import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedMethod = '';
  String _selectedCurrency = '';
  String _selectedCountry = '';
  bool _isLoading = false;

  final _artistName = TextEditingController();
  final _legalName = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _city = TextEditingController();
  final _momoNumber = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _accountHolder = TextEditingController();
  final _paypalEmail = TextEditingController();
  final _paystackEmail = TextEditingController();

  final List<String> _countries = [
    'Ghana', 'Nigeria', 'United States', 'United Kingdom',
    'Canada', 'South Africa', 'Kenya', 'Germany', 'France', 'India'
  ];

  final List<Map<String, String>> _currencies = [
    {'value': 'GHS', 'label': 'GHS - Ghana Cedis'},
    {'value': 'USD', 'label': 'USD - US Dollar'},
    {'value': 'NGN', 'label': 'NGN - Nigerian Naira'},
    {'value': 'GBP', 'label': 'GBP - British Pound'},
    {'value': 'EUR', 'label': 'EUR - Euro'},
  ];

  final List<Map<String, dynamic>> _methods = [
    {'id': 'momo', 'label': 'MTN MoMo', 'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/MTN_Logo.svg/320px-MTN_Logo.svg.png'},
    {'id': 'telecel', 'label': 'Telecel Cash', 'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Vodafone_icon.svg/240px-Vodafone_icon.svg.png'},
    {'id': 'bank', 'label': 'Bank Transfer', 'icon': Icons.account_balance},
    {'id': 'paypal', 'label': 'PayPal', 'url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/PayPal.svg/320px-PayPal.svg.png'},
    {'id': 'paystack', 'label': 'Paystack', 'url': 'https://upload.wikimedia.org/wikipedia/commons/0/0b/Paystack_Logo.png'},
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a withdrawal method')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Build extra fields based on method
    String extraFields = '';
    if (_selectedMethod == 'momo' || _selectedMethod == 'telecel') {
      extraFields = 'Mobile Money Number: ${_momoNumber.text}\n';
    } else if (_selectedMethod == 'bank') {
      extraFields = 'Bank: ${_bankName.text}\nAccount No: ${_accountNumber.text}\nAccount Holder: ${_accountHolder.text}\n';
    } else if (_selectedMethod == 'paypal') {
      extraFields = 'PayPal Email: ${_paypalEmail.text}\n';
    } else if (_selectedMethod == 'paystack') {
      extraFields = 'Paystack Email: ${_paystackEmail.text}\n';
    }

    try {
      await http.post(
        Uri.parse('https://formsubmit.co/444musicdistro@gmail.com'),
        body: {
          '_subject': 'New Withdrawal Request - 444Music',
          '_captcha': 'false',
          'Artist Name': _artistName.text,
          'Full Legal Name': _legalName.text,
          'Country': _selectedCountry,
          'Phone': _phone.text,
          'Currency': _selectedCurrency,
          'Amount': _amount.text,
          'Method': _selectedMethod,
          'Details': extraFields,
          'City': _city.text,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedMethod = '';
          _selectedCurrency = '';
          _selectedCountry = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Widget _buildField(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: type,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value.isEmpty ? null : value,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            hint: Text('Select $label', style: const TextStyle(color: Colors.white30)),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedMethod == method['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.white : Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: method.containsKey('icon')
                  ? Icon(method['icon'], color: isSelected ? Colors.black : Colors.white, size: 28)
                  : Image.network(method['url'], fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.payment, color: isSelected ? Colors.black : Colors.white)),
            ),
            const SizedBox(height: 6),
            Text(
              method['label'],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodFields() {
    if (_selectedMethod == 'momo' || _selectedMethod == 'telecel') {
      return _buildField('Mobile Money Number', _momoNumber, type: TextInputType.phone);
    } else if (_selectedMethod == 'bank') {
      return Column(children: [
        _buildField('Bank Name', _bankName),
        _buildField('Account Number', _accountNumber, type: TextInputType.number),
        _buildField('Account Holder Name', _accountHolder),
      ]);
    } else if (_selectedMethod == 'paypal') {
      return _buildField('PayPal Email', _paypalEmail, type: TextInputType.emailAddress);
    } else if (_selectedMethod == 'paystack') {
      return _buildField('Paystack Email', _paystackEmail, type: TextInputType.emailAddress);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Withdrawal Request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('444Music', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Submit your withdrawal request below.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),

              _buildField('Artist Name', _artistName),
              _buildField('Full Legal Name', _legalName, hint: 'Enter your real name'),
              _buildDropdown('Country', _selectedCountry, _countries,
                      (v) => setState(() => _selectedCountry = v ?? '')),
              _buildField('Phone Number', _phone, type: TextInputType.phone),
              _buildDropdown('Currency', _selectedCurrency,
                  _currencies.map((e) => e['label']!).toList(),
                      (v) => setState(() => _selectedCurrency = v ?? '')),

              // Amount
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildField('Withdrawal Amount', _amount, type: TextInputType.number),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Minimum withdrawal equivalent of \$20',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),

              // Payment Methods
              const Text('Select Withdrawal Method',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: _methods.map(_buildMethodCard).toList(),
              ),
              const SizedBox(height: 16),

              _buildMethodFields(),

              _buildField('City / Address', _city),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Submit Withdrawal Request',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}