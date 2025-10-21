import 'package:flutter/material.dart';
import 'dart:ui';

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
    // Check if user has scrolled to the bottom
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
                        const Text(
                          'سیاست حفظ حریم خصوصی',
                          style: TextStyle(
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
                            'مقدمه',
                            'فروشگاه G4A4 ضمن احترام به حریم خصوصی کاربران، متعهد به حفاظت از اطلاعات شخصی شما است. این سیاست توضیح می‌دهد که چگونه اطلاعات شما را جمع‌آوری، استفاده و محافظت می‌کنیم.',
                          ),
                          _buildSection(
                            '۱. اطلاعات جمع‌آوری شده',
                            'برای ارائه خدمات بهتر، ممکن است اطلاعات زیر را درخواست کنیم:\n\n'
                                '• شماره تلفن همراه\n'
                                '• آدرس ایمیل\n'
                                '• نام و نام خانوادگی\n'
                                '• آدرس پستی (برای ارسال سفارش)\n'
                                '• کد ملی (برای صدور فاکتور رسمی)\n\n'
                                'این اطلاعات برای پردازش سفارشات، ارسال محصولات و ارتباط با شما مورد استفاده قرار می‌گیرد.',
                          ),
                          _buildSection(
                            '۲. نحوه استفاده از اطلاعات',
                            'اطلاعات شما فقط برای موارد زیر استفاده می‌شود:\n\n'
                                '• پردازش و ارسال سفارشات\n'
                                '• ارسال اطلاعات و به‌روزرسانی‌های مرتبط با سفارش\n'
                                '• پاسخگویی به درخواست‌ها و سوالات\n'
                                '• بهبود کیفیت خدمات\n'
                                '• صدور فاکتور رسمی مطابق قوانین تجارت الکترونیک',
                          ),
                          _buildSection(
                            '۳. اطلاعات تماس رسمی',
                            'آدرس ایمیل و شماره تلفن‌هایی که در پروفایل خود ثبت می‌کنید، به عنوان آدرس رسمی و مورد تایید شما محسوب می‌شود. تمام مکاتبات و پاسخ‌های فروشگاه از طریق همین اطلاعات انجام خواهد شد.\n\n'
                                'در صورت عدم دقت در درج اطلاعات، فروشگاه می‌تواند جهت اطمینان از صحت سفارش، اطلاعات تکمیلی درخواست کند.',
                          ),
                          _buildSection(
                            '۴. حفاظت از اطلاعات',
                            'ما از بالاترین استانداردهای امنیتی برای محافظت از اطلاعات شما استفاده می‌کنیم:\n\n'
                                '• تمام اطلاعات احراز هویت به صورت رمزگذاری شده ذخیره می‌شوند\n'
                                '• استفاده از پروتکل‌های امنیتی SSL/TLS\n'
                                '• محدود کردن دسترسی به اطلاعات شخصی\n'
                                '• نظارت مستمر بر سیستم‌های امنیتی\n'
                                '• جلوگیری از دسترسی‌های غیرمجاز',
                          ),
                          _buildSection(
                            '۵. اشتراک‌گذاری اطلاعات',
                            'فروشگاه G4A4 هویت و اطلاعات شخصی کاربران را محرمانه تلقی می‌کند و به هیچ شخص یا سازمان ثالثی منتقل نمی‌کند، مگر در موارد زیر:\n\n'
                                '• الزام قانونی و ارائه به مراجع قضایی\n'
                                '• شرکای تحویل کالا (فقط اطلاعات ضروری برای ارسال)\n'
                                '• درگاه‌های پرداخت معتبر (برای تکمیل تراکنش)',
                          ),
                          _buildSection(
                            '۶. کوکی‌ها و IP',
                            'مانند سایر وب‌سایت‌ها، ما از کوکی‌ها و جمع‌آوری IP استفاده می‌کنیم تا:\n\n'
                                '• تجربه کاربری بهتری فراهم کنیم\n'
                                '• عملکرد سایت را بهبود دهیم\n'
                                '• آمار بازدید را تحلیل کنیم\n\n'
                                'شما می‌توانید از طریق تنظیمات مرورگر خود، کوکی‌ها را مدیریت کنید.',
                          ),
                          _buildSection(
                            '۷. نظرات و محتوای کاربران',
                            'فروشگاه ممکن است نظرات و پیام‌های کاربران را در راستای رعایت قوانین وب‌سایت ویرایش کند. در صورتی که محتوای ارسالی مشمول مصادیق محتوای مجرمانه باشد، فروشگاه می‌تواند از اطلاعات ثبت شده برای پیگیری قانونی استفاده کند.',
                          ),
                          _buildSection(
                            '۸. مسئولیت کاربران',
                            'حفظ و نگهداری رمز عبور بر عهده شماست. برای جلوگیری از هرگونه سوءاستفاده احتمالی:\n\n'
                                '• رمز عبور خود را محرمانه نگه دارید\n'
                                '• آن را برای دیگران فاش نکنید\n'
                                '• از رمزهای قوی استفاده کنید\n'
                                '• در صورت مشکوک بودن حساب، فوراً رمز را تغییر دهید',
                          ),
                          _buildSection(
                            '۹. تغییرات در سیاست حریم خصوصی',
                            'فروشگاه G4A4 این حق را برای خود محفوظ می‌دارد که این سیاست را در صورت نیاز به‌روزرسانی کند. تغییرات از طریق وب‌سایت اطلاع‌رسانی خواهد شد.',
                          ),
                          _buildSection(
                            '۱۰. تماس با ما',
                            'در صورت وجود هرگونه سوال، ابهام یا نگرانی در مورد حریم خصوصی خود، لطفاً با تیم پشتیبانی ما تماس بگیرید. ما همواره آماده پاسخگویی به شما هستیم.',
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
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '✓ تعهد ما',
                                  style: TextStyle(
                                    fontFamily: 'YekanBakh',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0071DF),
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'فروشگاه G4A4 برای حفاظت و نگهداری اطلاعات و حریم شخصی کاربران همه توان خود را به کار می‌گیرد و امیدوار است تجربه خریدی امن، راحت و خوشایند را برای همه کاربران فراهم آورد.',
                                  style: TextStyle(
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
                            const Padding(
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
                                    'لطفاً تا انتها اسکرول کنید',
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
                                  ? 'خواندم و موافقم'
                                  : 'لطفاً تا انتها بخوانید',
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

  Widget _buildSection(String title, String content) {
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
      ),
    );
  }
}
