import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Self-contained, bilingual in-app user guide. Explains install, linking,
/// roles, AI, links, UPS, history & alerts — no external docs needed.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final sections = _sections(isAr);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('helpTitle'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _SectionCard(section: sections[i], colors: colors),
      ),
    );
  }

  List<_Section> _sections(bool ar) => [
        _Section(
          icon: Icons.dashboard_customize,
          title: ar ? 'ما هو راصد؟' : 'What is Rased?',
          body: ar
              ? 'راصد لوحة مراقبة لخوادمك وحاوياتك (Docker) مع تحليل السجلات بالذكاء '
                  'الاصطناعي. يعرض كل جهاز كتبويب مستقل، مع رسوم حيّة، تنبيهات، UPS، وتاريخ.'
              : 'Rased is a dashboard for your servers and Docker containers, with AI '
                  'log analysis. Each machine shows as its own tab, with live charts, '
                  'alerts, UPS status and history.',
        ),
        _Section(
          icon: Icons.rocket_launch,
          title: ar ? 'التثبيت بأمر واحد' : 'One-command install',
          body: ar
              ? 'على الجهاز المركزي، داخل مجلد المشروع، نفّذ الأمر التالي. سيُنشئ ملف '
                  'الإعدادات بمفاتيح عشوائية تلقائياً ويسألك فقط عن عنوان الـ IP، ثم يشغّل كل شيء:'
              : 'On the central machine, inside the project folder, run the command below. '
                  'It auto-generates the config with random secrets, asks only for the server '
                  'IP, then starts everything:',
          code: 'bash scripts/install.sh',
        ),
        _Section(
          icon: Icons.person_add_alt,
          title: ar ? 'أول دخول' : 'First login',
          body: ar
              ? 'افتح اللوحة على المنفذ 8082، ثم سجّل حساباً. أول حساب يصبح "أدمن" '
                  'تلقائياً. الحسابات التالية تحتاج موافقتك من شاشة المستخدمين.'
              : 'Open the dashboard on port 8082 and register. The first account becomes '
                  'the admin automatically. Later accounts need your approval from the Users screen.',
        ),
        _Section(
          icon: Icons.add_to_queue,
          title: ar ? 'إضافة جهاز (LXC / خادم)' : 'Add a machine (LXC / server)',
          body: ar
              ? 'اضغط زر (+) في الأعلى. ستظهر لك خطوتان بأوامر جاهزة فيها المفاتيح '
                  'الحقيقية — انسخها فقط. الجهاز الجديد سيظهر كتبويب خلال ثوانٍ بعد تشغيله.'
              : 'Press the (+) button at the top. You will see two steps with ready commands '
                  'that already contain the real secrets — just copy them. The new machine '
                  'appears as a tab within seconds after it starts.',
        ),
        _Section(
          icon: Icons.admin_panel_settings,
          title: ar ? 'الصلاحيات والموافقة' : 'Roles & approval',
          body: ar
              ? 'الأدمن يتحكم بكل شيء (إيقاف/تشغيل الحاويات، الأسماء، الروابط، المستخدمين). '
                  'المستخدم العادي (viewer) يشاهد فقط. تدير الأدوار والموافقات من زر المستخدمين.'
              : 'Admins control everything (start/stop containers, names, links, users). '
                  'A viewer is read-only. Manage roles and approvals from the Users button.',
        ),
        _Section(
          icon: Icons.auto_awesome,
          title: ar ? 'إعداد الذكاء الاصطناعي' : 'AI setup',
          body: ar
              ? 'من الإعدادات اختر المزوّد (Ollama، LM Studio، Anthropic، OpenAI، أو مخصّص) '
                  'وأدخل الرابط والموديل والمفتاح. المفاتيح تُحفظ مشفّرة لكل مستخدم. بعدها '
                  'تقدر تحلّل سجلات أي حاوية أو تسأل المساعد عن الخادم.'
              : 'In Settings pick a provider (Ollama, LM Studio, Anthropic, OpenAI, or custom) '
                  'and enter the URL, model and key. Keys are stored encrypted per user. Then '
                  'you can analyze any container\'s logs or ask the assistant about the server.',
        ),
        _Section(
          icon: Icons.link,
          title: ar ? 'روابط الحاويات' : 'Container links',
          body: ar
              ? 'لكل حاوية، يقدر الأدمن يضيف رابطاً مخصّصاً (مثل واجهة الويب) من زر "تعديل '
                  'الرابط" في البطاقة. كما تتحوّل المنافذ المكشوفة إلى روابط قابلة للنقر تلقائياً.'
              : 'For each container, an admin can add a custom link (e.g. its web UI) from the '
                  '"Edit link" button on the card. Exposed ports also become clickable links automatically.',
        ),
        _Section(
          icon: Icons.battery_charging_full,
          title: ar ? 'إعداد UPS' : 'UPS setup',
          body: ar
              ? 'من زر إعدادات الجهاز (⚙️) أدخل عنوان خادم NUT واسم الـ UPS لعرض حالة '
                  'الطاقة والبطارية. تقدر أيضاً تعيد تسمية الجهاز أو الخادم من نفس النافذة.'
              : 'From the device settings button (⚙️) enter the NUT host and UPS name to show '
                  'power and battery status. You can also rename the machine or server from the same dialog.',
        ),
        _Section(
          icon: Icons.timeline,
          title: ar ? 'السجل والتنبيهات' : 'History & alerts',
          body: ar
              ? 'زر السجل يعرض رسوم الأداء (يوم / أسبوع / شهر). التنبيهات (CPU، ذاكرة، قرص، '
                  'توقّف، UPS) تظهر في اللوحة، ويمكن إرسالها إلى webhook (n8n / Telegram / Slack) '
                  'عبر ملف الإعدادات.'
              : 'The History button shows performance charts (day / week / month). Alerts (CPU, '
                  'memory, disk, downtime, UPS) appear on the dashboard and can be forwarded to a '
                  'webhook (n8n / Telegram / Slack) via the config file.',
        ),
      ];
}

class _Section {
  final IconData icon;
  final String title;
  final String body;
  final String? code;
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    this.code,
  });
}

class _SectionCard extends StatelessWidget {
  final _Section section;
  final RasedColors colors;
  const _SectionCard({required this.section, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(section.icon, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: TextStyle(
                  fontSize: 13, height: 1.6, color: colors.textSecondary),
            ),
            if (section.code != null) ...[
              const SizedBox(height: 10),
              _CommandBox(text: section.code!, colors: colors),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommandBox extends StatelessWidget {
  final String text;
  final RasedColors colors;
  const _CommandBox({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: colors.textPrimary,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          IconButton(
            tooltip: context.tr('copy'),
            icon: Icon(Icons.copy, size: 16, color: colors.textSecondary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('copied'))),
              );
            },
          ),
        ],
      ),
    );
  }
}
