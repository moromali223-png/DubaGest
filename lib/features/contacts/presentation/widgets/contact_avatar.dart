import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/contact.dart';

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.radius = 20});
  final Contact contact;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: contact.estArchive ? AppColors.border : AppColors.greenSoft,
        foregroundColor: contact.estArchive ? AppColors.muted : AppColors.green,
        child: contact.typePersonne == TypePersonne.organisation
            ? Icon(Icons.business_outlined, size: radius)
            : Text(
                contact.initiales,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: radius * 0.75),
              ),
      );
}
