import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // اضافه شده

class PrivacyPolicyDialog extends StatefulWidget {
  final VoidCallback? onAccept;
  final bool showAcceptButton;

  const PrivacyPolicyDialog({
    Key? key,
    this.onAccept,
    this.showAcceptButton = true,
  }) : super(key: key);

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onAccept,
    bool showAcceptButton = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !showAcceptButton,
      barrierColor: Colors.transparent,
      builder: (context) => PrivacyPolicyDialog(
        onAccept: onAccept,
        showAcceptButton: showAcceptButton,
      ),
    );
  }
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations =
        AppLocalizations.of(context)!; // استفاده از localizations
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? screenWidth * 0.1 : 20,
            vertical: isTablet ? screenHeight * 0.05 : 40,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 800 : screenWidth,
              maxHeight: screenHeight * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0071DF), Color(0xFF0052A3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          localizations.privacyPolicyTitle,
                          style: const TextStyle(
                            fontFamily: 'YekanBakh',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 40), // For symmetry
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            localizations.privacyPolicyIntroduction,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection1Title,
                            localizations.privacyPolicySection1Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection2Title,
                            localizations.privacyPolicySection2Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection3Title,
                            localizations.privacyPolicySection3Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection4Title,
                            localizations.privacyPolicySection4Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection5Title,
                            localizations.privacyPolicySection5Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection6Title,
                            localizations.privacyPolicySection6Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection7Title,
                            localizations.privacyPolicySection7Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection8Title,
                            localizations.privacyPolicySection8Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection9Title,
                            localizations.privacyPolicySection9Content,
                          ),
                          _buildSection(
                            localizations.privacyPolicySection10Title,
                            localizations.privacyPolicySection10Content,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF0071DF).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.privacyPolicyCommitmentTitle,
                                  style: const TextStyle(
                                    fontFamily: 'YekanBakh',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0071DF),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  localizations.privacyPolicyCommitmentContent,
                                  style: const TextStyle(
                                    fontFamily: 'YekanBakh',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.8,
                                    color: Color(0xFF424242),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Footer with Accept Button
                  if (widget.showAcceptButton)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (!_hasScrolledToBottom)
                            Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    size: 16,
                                    color: Color(0xFF757575),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    localizations?.privacyPolicyScrollToEnd ??
                                        'Scroll to end', // تغییر به localize
                                    style: TextStyle(
                                      fontFamily: 'YekanBakh',
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ElevatedButton(
                            onPressed: _hasScrolledToBottom
                                ? () {
                                    if (widget.onAccept != null) {
                                      widget.onAccept!();
                                    }
                                    Navigator.of(context).pop(true);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasScrolledToBottom
                                  ? const Color(0xFF0071DF)
                                  : Colors.grey[300],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 56),
                              elevation: _hasScrolledToBottom ? 2 : 0,
                            ),
                            child: Text(
                              _hasScrolledToBottom
                                  ? localizations
                                      .privacyPolicyAccept // تغییر به localize
                                  : localizations
                                      .privacyPolicyReadToEnd, // تغییر به localize
                              style: TextStyle(
                                fontFamily: 'YekanBakh',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _hasScrolledToBottom
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, [String? content]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'YekanBakh',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0071DF),
              height: 1.8,
            ),
            textAlign: TextAlign.right,
          ),
          if (content != null) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontFamily: 'YekanBakh',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.8,
                color: Color(0xFF424242),
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}
