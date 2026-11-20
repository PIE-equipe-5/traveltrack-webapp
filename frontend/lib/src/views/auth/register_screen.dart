import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:traveltrack/src/constants/app_strings.dart';
import 'package:traveltrack/src/models/auth_form_validators.dart';
import 'package:traveltrack/src/navigation/app_router.dart';
import 'package:traveltrack/src/viewmodels/auth_viewmodel.dart';
import 'package:traveltrack/src/widgets/auth_back_button.dart';
import 'package:traveltrack/src/widgets/auth_form_field.dart';
import 'package:traveltrack/src/widgets/auth_link_row.dart';
import 'package:traveltrack/src/widgets/auth_screen_header.dart';
import 'package:traveltrack/src/widgets/auth_submit_section.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  bool _acceptedTerms = false;

  /// Rend "conditions d'utilisation" cliquable sans cocher la case : ce
  /// geste l'emporte sur celui de la ligne entière.
  late final TapGestureRecognizer _termsOfUseLinkRecognizer;

  @override
  void initState() {
    super.initState();
    _termsOfUseLinkRecognizer = TapGestureRecognizer()
      ..onTap = _openTermsOfUse;
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _termsOfUseLinkRecognizer.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) return;
    if (!_formKey.currentState!.validate()) return;

    // Pas de navigation manuelle ici : GoRouter réagit automatiquement au
    // changement de session via `refreshListenable` + `redirect` (voir
    // app_router.dart) et nous enverra sur /map dès que l'inscription réussit.
    // Si une confirmation par email est requise, le ViewModel l'annonce.
    await authViewModel.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    );
  }

  /// Ouvre les conditions par-dessus le formulaire, pour que la flèche retour
  /// ramène à la saisie en cours sans la perdre.
  void _openTermsOfUse() {
    context.push(termsOfUseLocation);
  }

  void _goToLogin() {
    authViewModel.clearMessages();
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthBackButton(onPressed: _goToLogin),
                const SizedBox(height: 16),

                const AuthScreenHeader(
                  title: 'Créer un compte',
                  subtitle: 'Rejoins-nous et commence l\'aventure',
                ),
                const SizedBox(height: 32),

                AuthFormField(
                  label: 'Prénom',
                  hintText: 'Jean',
                  controller: _firstNameController,
                ),
                const SizedBox(height: 16),

                AuthFormField(
                  label: 'Nom',
                  hintText: 'Dupont',
                  controller: _lastNameController,
                ),
                const SizedBox(height: 16),

                ListenableBuilder(
                  listenable: authViewModel,
                  builder: (context, _) => AuthFormField(
                    label: 'Email',
                    hintText: 'exemple@email.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => authViewModel.clearMessages(),
                    validator: AuthFormValidators.validateEmail,
                    forcedErrorText: authViewModel.emailErrorMessage,
                  ),
                ),
                const SizedBox(height: 16),

                AuthFormField(
                  label: 'Mot de passe',
                  hintText: '••••••••',
                  controller: _passwordController,
                  isPassword: true,
                  onChanged: (_) => authViewModel.clearMessages(),
                  validator: AuthFormValidators.validateNewPassword,
                ),
                const SizedBox(height: 16),

                AuthFormField(
                  label: 'Confirmer le mot de passe',
                  hintText: '••••••••',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  onChanged: (_) => authViewModel.clearMessages(),
                  validator: (enteredConfirmation) =>
                      AuthFormValidators.validatePasswordConfirmation(
                        enteredConfirmation,
                        _passwordController.text,
                      ),
                ),
                const SizedBox(height: 20),

                // Case et texte cochent l'acceptation ; seul le lien ouvre
                // les conditions.
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text.rich(
                    TextSpan(
                      text: AppStrings.termsAcceptancePrefix,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                      children: [
                        TextSpan(
                          text: AppStrings.termsOfUseLinkLabel,
                          recognizer: _termsOfUseLinkRecognizer,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ListenableBuilder(
                  listenable: authViewModel,
                  builder: (context, _) => AuthSubmitSection(
                    label: 'Créer un compte',
                    onSubmit: _acceptedTerms ? _submit : null,
                    isLoading: authViewModel.isLoading,
                    errorMessage: authViewModel.errorMessage,
                    successMessage: authViewModel.successMessage,
                  ),
                ),
                const SizedBox(height: 20),

                AuthLinkRow(
                  message: 'Tu as déjà un compte ?',
                  linkLabel: 'Se connecter',
                  onLinkPressed: _goToLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
