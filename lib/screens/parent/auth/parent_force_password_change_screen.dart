import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';

class ParentForcePasswordChangeScreen extends StatefulWidget {
  final VoidCallback? onPasswordChanged;

  const ParentForcePasswordChangeScreen({
    Key? key,
    this.onPasswordChanged,
  }) : super(key: key);

  @override
  State<ParentForcePasswordChangeScreen> createState() => _ParentForcePasswordChangeScreenState();
}

class _ParentForcePasswordChangeScreenState extends State<ParentForcePasswordChangeScreen> {
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Colors.blue.shade700,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue.shade600, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Change Your Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'First-time setup required',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You must set a new password before accessing your account.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Current password
                  _buildPasswordField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    hint: 'Enter your current password',
                    showPassword: _showCurrentPassword,
                    onToggle: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Current password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // New password
                  _buildPasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    hint: 'Enter a new password (minimum 8 characters)',
                    showPassword: _showNewPassword,
                    onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'New password is required';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (value == _currentPasswordController.text) {
                        return 'New password must be different from current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm password
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    hint: 'Re-enter your new password',
                    showPassword: _showConfirmPassword,
                    onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Password requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password Requirements:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRequirement('At least 8 characters', _newPasswordController.text.length >= 8),
                        _buildRequirement('Different from current', _newPasswordController.text.isNotEmpty && _newPasswordController.text != _currentPasswordController.text),
                        _buildRequirement('Matches confirmation', _newPasswordController.text == _confirmPasswordController.text && _newPasswordController.text.isNotEmpty),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitPasswordChange,
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.check),
                      label: Text(_isLoading ? 'Updating…' : 'Update Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        disabledBackgroundColor: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            showPassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPasswordChange() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.completeParentPasswordChange(
        oldPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully! Redirecting…'),
            backgroundColor: Colors.green,
          ),
        );

        // Call callback or navigate
        await Future.delayed(const Duration(seconds: 1));
        widget.onPasswordChanged?.call();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
