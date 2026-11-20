import 'package:flutter/material.dart';

/// Champ de formulaire avec libellé. Si [isPassword] est vrai, la saisie est
/// masquée et un bouton permet de l'afficher.
///
/// Chaque champ se vérifie seul, pour ne jamais signaler en rouge un champ
/// que l'utilisateur n'a pas encore rempli :
/// - pendant la première saisie, aucune erreur n'est affichée ;
/// - en quittant le champ après y avoir écrit, l'erreur éventuelle apparaît ;
/// - ensuite, et après un envoi du formulaire raté, l'erreur se met à jour à
///   chaque frappe et disparaît dès que la saisie est corrigée.
class AuthFormField extends StatefulWidget {
  const AuthFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.isPassword = false,
    this.forcedErrorText,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool isPassword;

  /// Erreur venant du serveur, affichée à la place de celle du [validator].
  final String? forcedErrorText;

  @override
  State<AuthFormField> createState() => _AuthFormFieldState();
}

class _AuthFormFieldState extends State<AuthFormField> {
  final _textFieldKey = GlobalKey<FormFieldState<String>>();
  final _focusNode = FocusNode();
  bool _isTextObscured = true;
  bool _isLiveValidationEnabled = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_enableLiveValidationAfterFilledFieldIsLeft);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_enableLiveValidationAfterFilledFieldIsLeft)
      ..dispose();
    super.dispose();
  }

  void _enableLiveValidationAfterFilledFieldIsLeft() {
    final hasLeftFilledField =
        !_focusNode.hasFocus && widget.controller.text.isNotEmpty;
    if (hasLeftFilledField) _enableLiveValidation();
  }

  void _onTextChanged(String enteredText) {
    // Le champ a été signalé par l'envoi du formulaire : on suit désormais la
    // saisie pour retirer l'erreur dès qu'elle est corrigée.
    if (_textFieldKey.currentState?.hasError ?? false) _enableLiveValidation();
    widget.onChanged?.call(enteredText);
  }

  void _enableLiveValidation() {
    if (_isLiveValidationEnabled) return;
    setState(() => _isLiveValidationEnabled = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          key: _textFieldKey,
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword && _isTextObscured,
          onChanged: _onTextChanged,
          validator: widget.validator,
          autovalidateMode: _isLiveValidationEnabled
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          forceErrorText: widget.forcedErrorText,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _isTextObscured ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _isTextObscured = !_isTextObscured);
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
