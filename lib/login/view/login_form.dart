import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:phone_authentication_project/login/cubit/login_cubit.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;

  String _phoneNumber = '';
  String? _verificationId;
  PhoneNumber _initialNumber = PhoneNumber(isoCode: 'ZW');

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _otpController = TextEditingController();

    context.read<LoginCubit>().getSavedPhoneNumber().then((savedPhoneNumber) {
      if (!mounted || savedPhoneNumber == null || savedPhoneNumber.isEmpty) {
        return;
      }
      setState(() {
        _phoneController.text = savedPhoneNumber;
        _phoneNumber = _normalizePhoneNumber(savedPhoneNumber);
      });

      PhoneNumber.getRegionInfoFromPhoneNumber(savedPhoneNumber)
          .then((parsedNumber) {
        if (!mounted) return;
        setState(() {
          _initialNumber = parsedNumber;
        });
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is LoginCodeSent) {
          setState(() {
            _verificationId = state.verificationId;
            _otpController.clear();
          });
          _showSnack('Verification code sent.', isError: false);
          return;
        }

        if (state is LoginFailure) {
          _showSnack(state.errorMessage, isError: true);
          return;
        }

        if (state is LoginSuccess) {
          _showSnack('Verification successful.', isError: false);
        }
      },
      builder: (context, state) {
        final isLoading = state is LoginLoading;
        final loadingMessage = state is LoginLoading ? state.message : null;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFE),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8EBF2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x17000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _verificationId == null
                        ? _PhoneStep(
                            key: const ValueKey('phone-step'),
                            controller: _phoneController,
                            initialNumber: _initialNumber,
                            isLoading: isLoading,
                            loadingMessage: loadingMessage,
                            onChanged: (value) {
                              _phoneNumber = _normalizePhoneNumber(value);
                            },
                            onSubmit: _submitPhoneNumber,
                          )
                        : _OtpStep(
                            key: const ValueKey('otp-step'),
                            controller: _otpController,
                            phoneNumber: _phoneNumber,
                            isLoading: isLoading,
                            loadingMessage: loadingMessage,
                            onChanged: (_) => setState(() {}),
                            onBack: _resetToPhoneStep,
                            onSubmit: _submitOtpCode,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isValidPhoneNumber(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }

  String _normalizePhoneNumber(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  void _submitPhoneNumber() {
    FocusScope.of(context).unfocus();
    final enteredPhone = _normalizePhoneNumber(
      _phoneNumber.isEmpty ? _phoneController.text : _phoneNumber,
    );

    if (!_isValidPhoneNumber(enteredPhone)) {
      _showSnack(
        'Enter a valid phone number with country code.',
        isError: true,
      );
      return;
    }

    _phoneNumber = enteredPhone;
    context.read<LoginCubit>().verifyPhoneNumber(enteredPhone);
  }

  void _submitOtpCode() {
    FocusScope.of(context).unfocus();
    final verificationId = _verificationId;
    final smsCode = _otpController.text.trim();

    if (verificationId == null || verificationId.isEmpty) {
      _showSnack(
        'Verification session missing. Request a new code.',
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      _showSnack('Enter the 6-digit SMS code.', isError: true);
      return;
    }

    context.read<LoginCubit>().verifySmsCode(smsCode, verificationId);
  }

  void _resetToPhoneStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _verificationId = null;
      _otpController.clear();
    });
  }

  void _showSnack(String message, {required bool isError}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB42318) : const Color(0xFF027A48),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.controller,
    required this.initialNumber,
    required this.isLoading,
    required this.loadingMessage,
    required this.onChanged,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final PhoneNumber initialNumber;
  final bool isLoading;
  final String? loadingMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign in',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Use your phone number to receive a secure verification code.',
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Color(0xFF475467),
          ),
        ),
        const SizedBox(height: 22),
        InternationalPhoneNumberInput(
          onInputChanged: (number) => onChanged(number.phoneNumber ?? ''),
          selectorConfig: const SelectorConfig(
            selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
            useBottomSheetSafeArea: true,
          ),
          initialValue: initialNumber,
          textFieldController: controller,
          autoValidateMode: AutovalidateMode.disabled,
          selectorTextStyle: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          formatInput: true,
          inputDecoration: InputDecoration(
            labelText: 'Phone number',
            hintText: '77 123 4567',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0B7A75), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B7A75),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send Verification Code',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        if (loadingMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            loadingMessage!,
            style: const TextStyle(color: Color(0xFF344054)),
          ),
        ],
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.phoneNumber,
    required this.isLoading,
    required this.loadingMessage,
    required this.onChanged,
    required this.onBack,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final String phoneNumber;
  final bool isLoading;
  final String? loadingMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isOtpValid = RegExp(r'^\d{6}$').hasMatch(controller.text.trim());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify number',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to $phoneNumber',
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Color(0xFF475467),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'SMS code',
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0B7A75), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading || !isOtpValid ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B7A75),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Verify Code',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: isLoading ? null : onBack,
            child: const Text('Use a different number'),
          ),
        ),
        if (loadingMessage != null) ...[
          Text(
            loadingMessage!,
            style: const TextStyle(color: Color(0xFF344054)),
          ),
        ],
      ],
    );
  }
}
