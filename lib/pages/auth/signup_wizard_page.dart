import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupWizardPage extends StatefulWidget {
  const SignupWizardPage({super.key});

  @override
  State<SignupWizardPage> createState() => _SignupWizardPageState();
}

class _SignupWizardPageState extends State<SignupWizardPage> {
  final _page = PageController();
  int _step = 0;

  // Step 1
  final _userId = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  // Step 2
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();

  // Step 3
  DateTime _dob = DateTime(2002, 1, 1);
  String _gender = 'Male';

  // Step 4
  bool _heightInCm = true; // else ft/in
  double _heightCm = 170;
  int _feet = 5;
  int _inch = 7;

  bool _weightInKg = true; // else lbs
  double _weightKg = 70;
  double _weightLbs = 154;

  // Step 5
  final List<String> _goals = [
    'Weight Loss',
    'Muscle Gain',
    'Strength',
    'Yoga',
    'Cardio Fitness',
    'Boxing',
    'Pilates',
    'Zumba',
    'Calisthenics',
    'Nutrition',
  ];
  final Set<String> _selectedGoals = {'Weight Loss'};
  String _role = 'Client';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _page.dispose();
    _userId.dispose();
    _email.dispose();
    _pass.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  double get _heightMeters {
    final cm = _heightInCm ? _heightCm : ((_feet * 30.48) + (_inch * 2.54));
    return cm / 100.0;
  }

  double get _weightKgResolved {
    return _weightInKg ? _weightKg : (_weightLbs * 0.45359237);
  }

  double get _bmi {
    final h = _heightMeters;
    if (h <= 0) return 0;
    return _weightKgResolved / (h * h);
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_step < 4) {
      setState(() => _step++);
      _page.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _page.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;

      // Convert height to cm and weight to kg for storage
      final heightCm = _heightInCm ? _heightCm : ((_feet * 30.48) + (_inch * 2.54));
      final weightKg = _weightInKg ? _weightKg : (_weightLbs * 0.45359237);

      // Sign up with Supabase
      final response = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _pass.text,
        data: {
          'user_id': _userId.text.trim(),
          'first_name': _first.text.trim(),
          'last_name': _last.text.trim(),
          'phone': '+91${_phone.text.trim()}',
          'dob': _dob.toIso8601String(),
          'gender': _gender,
          'height_cm': heightCm,
          'weight_kg': weightKg,
          'bmi': _bmi,
          'goals': _selectedGoals.toList(),
          'role': _role.toLowerCase(),
        },
      );

      if (!mounted) return;

      if (response.user != null) {
        // Success - navigate to home
        context.go('/home');
      } else {
        throw Exception('Signup failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (_step + 1) / 5;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      'Create account',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Step ${_step + 1}/5',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Container(color: cs.surfaceContainerHighest.withOpacity(0.35)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        width: MediaQuery.of(context).size.width * progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.primary.withOpacity(0.55)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                  ),
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _Step1(userId: _userId, email: _email, pass: _pass),
                      _Step2(first: _first, last: _last, phone: _phone),
                      _Step3(
                        dob: _dob,
                        gender: _gender,
                        onDobChanged: (d) {
                          HapticFeedback.selectionClick();
                          setState(() => _dob = d);
                        },
                        onGender: (g) {
                          HapticFeedback.selectionClick();
                          setState(() => _gender = g);
                        },
                      ),
                      _Step4(
                        heightInCm: _heightInCm,
                        weightInKg: _weightInKg,
                        heightCm: _heightCm,
                        feet: _feet,
                        inch: _inch,
                        weightKg: _weightKg,
                        weightLbs: _weightLbs,
                        bmi: _bmi,
                        onToggleHeightUnit: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _heightInCm = v);
                        },
                        onToggleWeightUnit: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _weightInKg = v);
                        },
                        onHeightCm: (v) => setState(() => _heightCm = v),
                        onFeet: (v) => setState(() => _feet = v),
                        onInch: (v) => setState(() => _inch = v),
                        onWeightKg: (v) => setState(() => _weightKg = v),
                        onWeightLbs: (v) => setState(() => _weightLbs = v),
                      ),
                      _Step5(
                        goals: _goals,
                        selected: _selectedGoals,
                        role: _role,
                        onToggleGoal: (g) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_selectedGoals.contains(g) && _selectedGoals.length > 1) {
                              _selectedGoals.remove(g);
                            } else {
                              _selectedGoals.add(g);
                            }
                          });
                        },
                        onRole: (r) {
                          HapticFeedback.selectionClick();
                          setState(() => _role = r);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryButton(
                text: _step == 4 ? 'Submit' : 'Next',
                onTap: _isSubmitting ? null : _next,
                isLoading: _isSubmitting,
              ),
              const SizedBox(height: 10),
              Text(
                'We email from noreply@cotrainr.com',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final TextEditingController userId;
  final TextEditingController email;
  final TextEditingController pass;

  const _Step1({required this.userId, required this.email, required this.pass});

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 1: Credentials',
      subtitle: 'Set your user id, email, and password.',
      child: Column(
        children: [
          _Field(
            label: 'User ID',
            controller: userId,
            keyboardType: TextInputType.text,
            prefix: const Icon(Icons.alternate_email),
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Email',
            controller: email,
            keyboardType: TextInputType.emailAddress,
            prefix: const Icon(Icons.mail_outline),
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Password',
            controller: pass,
            obscureText: true,
            prefix: const Icon(Icons.lock_outline),
          ),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final TextEditingController first;
  final TextEditingController last;
  final TextEditingController phone;

  const _Step2({required this.first, required this.last, required this.phone});

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'Step 2: Profile',
      subtitle: 'Your name and Indian phone number.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'First name',
                  controller: first,
                  prefix: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Last name',
                  controller: last,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Phone (India)',
            controller: phone,
            keyboardType: TextInputType.phone,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Center(child: Text('+91')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final DateTime dob;
  final String gender;
  final ValueChanged<DateTime> onDobChanged;
  final ValueChanged<String> onGender;

  const _Step3({
    required this.dob,
    required this.gender,
    required this.onDobChanged,
    required this.onGender,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _StepShell(
      title: 'Step 3: DOB and Gender',
      subtitle: 'Use the rotator picker for date.',
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            ),
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                primaryColor: cs.primary,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: dob,
                maximumDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                minimumDate: DateTime(1950, 1, 1),
                onDateTimeChanged: onDobChanged,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ChoiceChip(
                text: 'Male',
                selected: gender == 'Male',
                onTap: () => onGender('Male'),
              ),
              const SizedBox(width: 10),
              _ChoiceChip(
                text: 'Female',
                selected: gender == 'Female',
                onTap: () => onGender('Female'),
              ),
              const SizedBox(width: 10),
              _ChoiceChip(
                text: 'Other',
                selected: gender == 'Other',
                onTap: () => onGender('Other'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step4 extends StatelessWidget {
  final bool heightInCm;
  final bool weightInKg;

  final double heightCm;
  final int feet;
  final int inch;

  final double weightKg;
  final double weightLbs;

  final double bmi;

  final ValueChanged<bool> onToggleHeightUnit;
  final ValueChanged<bool> onToggleWeightUnit;

  final ValueChanged<double> onHeightCm;
  final ValueChanged<int> onFeet;
  final ValueChanged<int> onInch;

  final ValueChanged<double> onWeightKg;
  final ValueChanged<double> onWeightLbs;

  const _Step4({
    required this.heightInCm,
    required this.weightInKg,
    required this.heightCm,
    required this.feet,
    required this.inch,
    required this.weightKg,
    required this.weightLbs,
    required this.bmi,
    required this.onToggleHeightUnit,
    required this.onToggleWeightUnit,
    required this.onHeightCm,
    required this.onFeet,
    required this.onInch,
    required this.onWeightKg,
    required this.onWeightLbs,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _StepShell(
      title: 'Step 4: Height and Weight',
      subtitle: 'Toggle units, we will store canonical values in backend.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Height', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              _TogglePill(
                left: 'cm',
                right: 'ft/in',
                isLeft: heightInCm,
                onChanged: onToggleHeightUnit,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: heightInCm
                ? _NumberField(
                    key: const ValueKey('cm'),
                    label: 'Height (cm)',
                    value: heightCm.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n != null) onHeightCm(n.clamp(80, 230));
                    },
                  )
                : Row(
                    key: const ValueKey('ftin'),
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Feet',
                          value: '$feet',
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null) onFeet(n.clamp(3, 8));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Inches',
                          value: '$inch',
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null) onInch(n.clamp(0, 11));
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Text('Weight', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              _TogglePill(
                left: 'kg',
                right: 'lbs',
                isLeft: weightInKg,
                onChanged: onToggleWeightUnit,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: cs.primary.withOpacity(0.25)),
                ),
                child: Text(
                  'BMI ${bmi.isFinite ? bmi.toStringAsFixed(1) : '--'}',
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: weightInKg
                ? _NumberField(
                    key: const ValueKey('kg'),
                    label: 'Weight (kg)',
                    value: weightKg.toStringAsFixed(1),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n != null) onWeightKg(n.clamp(20, 250));
                    },
                  )
                : _NumberField(
                    key: const ValueKey('lbs'),
                    label: 'Weight (lbs)',
                    value: weightLbs.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n != null) onWeightLbs(n.clamp(44, 550));
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'BMI shown here is preview. Store height/weight in backend, compute BMI there too.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Step5 extends StatelessWidget {
  final List<String> goals;
  final Set<String> selected;
  final String role;
  final ValueChanged<String> onToggleGoal;
  final ValueChanged<String> onRole;

  const _Step5({
    required this.goals,
    required this.selected,
    required this.role,
    required this.onToggleGoal,
    required this.onRole,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _StepShell(
      title: 'Step 5: Goal and Role',
      subtitle: 'Choose your focus and role.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Goal category', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: goals.map((g) {
              final isOn = selected.contains(g);
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onToggleGoal(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isOn ? cs.primary.withOpacity(0.20) : cs.surface.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isOn ? cs.primary.withOpacity(0.55) : cs.outlineVariant.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isOn ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text('Role', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  text: 'Client',
                  selected: role == 'Client',
                  onTap: () => onRole('Client'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceChip(
                  text: 'Trainer',
                  selected: role == 'Trainer',
                  onTap: () => onRole('Trainer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Note: Trainer verification (certificates, gov id) can be collected after signup on a separate flow.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const _Field({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.prefix,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: cs.surface.withOpacity(0.40),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  final String label;
  final String value;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: cs.surface.withOpacity(0.40),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const _PrimaryButton({required this.text, this.onTap, this.isLoading = false});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  late final Animation<double> _s =
      Tween(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapCancel: () => _c.reverse(),
      onTapUp: (_) => _c.reverse(),
      onTap: widget.onTap == null || widget.isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
      child: ScaleTransition(
        scale: _s,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.70)],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.20),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                  ),
                )
              : Text(
                  widget.text,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.18) : cs.surface.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.55) : cs.outlineVariant.withOpacity(0.35),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChanged;

  const _TogglePill({
    required this.left,
    required this.right,
    required this.isLeft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniToggle(
            text: left,
            selected: isLeft,
            onTap: () => onChanged(true),
          ),
          _MiniToggle(
            text: right,
            selected: !isLeft,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _MiniToggle({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
