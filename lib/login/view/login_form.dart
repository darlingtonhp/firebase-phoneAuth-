import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:phone_authentication_project/login/cubit/login_cubit.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  late final TextEditingController _phone;
  final OtpFieldController _smsCode = OtpFieldController();
  String otpCode = '';

  String phoneNumber = '';
  String initialCountry = 'ZW';
  PhoneNumber number = PhoneNumber(isoCode: 'ZW');

  @override
  void initState() {
    _phone = TextEditingController();

    // Retrieve the saved phone number if it exists, otherwise use the newly entered number
    BlocProvider.of<LoginCubit>(context)
        .getSavedPhoneNumber()
        .then((savedPhoneNumber) {
      if (savedPhoneNumber != null) {
        setState(() {
          phoneNumber = savedPhoneNumber;
          _phone.text = phoneNumber; // Set text to the controller
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is LoginFailure) {
          // Show error message to the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'An error occured!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is LoginSmsCodeSent) {
          final verificationId = state.verificationId;
          return Column(
            children: [
              const Text('Enter SMS verification code'),
              OTPTextField(
                controller: _smsCode,
                length: 6,
                width: MediaQuery.of(context).size.width,
                fieldWidth: 80,
                style: const TextStyle(fontSize: 17),
                textFieldAlignment: MainAxisAlignment.spaceAround,
                fieldStyle: FieldStyle.underline,
                onChanged: (pin) {
                  otpCode = pin;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  context
                      .read<LoginCubit>()
                      .verifySmsCode(otpCode, verificationId);
                  _smsCode.clear();
                },
                child: const Text('Verify Sms'),
              ),
            ],
          );
        } else {
          return Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (PhoneNumber number) {
                      setState(() {
                        phoneNumber = number.phoneNumber ?? '';
                      });
                    },
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                      useBottomSheetSafeArea: true,
                    ),
                    ignoreBlank: false,
                    autoValidateMode: AutovalidateMode.disabled,
                    selectorTextStyle: const TextStyle(color: Colors.black),
                    initialValue: number,
                    textFieldController: _phone,
                    formatInput: true,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    inputBorder: const OutlineInputBorder(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      context.read<LoginCubit>().verifyPhoneNumber(phoneNumber);
                    }
                  },
                  child: const Text('Verify'),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
