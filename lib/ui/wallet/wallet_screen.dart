import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/wallet_controller.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/wallet_transaction_model.dart';
import 'package:driver/model/withdraw_model.dart';
import 'package:driver/payment/createRazorPayOrderModel.dart';
import 'package:driver/payment/rozorpayConroller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/ui/order_intercity_screen/complete_intecity_order_screen.dart';
import 'package:driver/ui/order_screen/complete_order_screen.dart';
import 'package:driver/ui/withdraw_history/withdraw_history_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:driver/ui/recargar_wallet/recargar_screen.dart';
//here

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<WalletController>(
        init: WalletController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: controller.isLoading.value
                ? Constant.loader(context)
                : Column(
                    children: [
                      Container(
                        height: Responsive.width(30, context),
                        width: Responsive.width(100, context),
                        color: AppColors.primary,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                      "Total Balance".tr,
                                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                                    ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Bs.- ${controller.driverUserModel.value.walletAmount.toString()}",
                                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 28),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.background, 
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: controller.transactionList.isEmpty
                                ? Center(child: Text("No transaction found".tr,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: controller.transactionList.length,
                                    itemBuilder: (context, index) {
                                      WalletTransactionModel walletTransactionModel = controller.transactionList[index];
                                      return InkWell(
                                        onTap: () async {
                                          if (walletTransactionModel.orderType == "city") {
                                            await FireStoreUtils.getOrder(walletTransactionModel.transactionId.toString()).then((value) {
                                              if (value != null) {
                                                OrderModel orderModel = value;
                                                Get.to(const CompleteOrderScreen(), arguments: {
                                                  "orderModel": orderModel,
                                                });
                                              }
                                            });
                                          } else if (walletTransactionModel.orderType == "intercity") {
                                            await FireStoreUtils.getInterCityOrder(walletTransactionModel.transactionId.toString()).then((value) {
                                              if (value != null) {
                                                InterCityOrderModel orderModel = value;
                                                Get.to(const CompleteIntercityOrderScreen(), arguments: {
                                                  "orderModel": orderModel,
                                                });
                                              }
                                            });
                                          } else {
                                            // No mostrar detalles de transacción
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                              decoration: BoxDecoration(
                                                color: themeChange.getThem() ? AppColors.darkContainerBackground : AppColors.containerBackground,
                                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                border: Border.all(color: themeChange.getThem() ? AppColors.darkContainerBorder : AppColors.containerBorder, width: 0.5),
                                                boxShadow: themeChange.getThem()
                                                    ? null
                                                    : [
                                                        BoxShadow(
                                                          color: Colors.grey.withOpacity(0.5),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2), // changes position of shadow
                                                        ),
                                                      ],
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                        decoration: BoxDecoration(color: AppColors.lightGray, borderRadius: BorderRadius.circular(50)),
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(12.0),
                                                          child: SvgPicture.asset(
                                                            'assets/icons/ic_wallet.svg',
                                                            width: 24,
                                                            color: Colors.black,
                                                          ),
                                                        )),
                                                    const SizedBox(
                                                      width: 10,
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  Constant.dateFormatTimestamp(walletTransactionModel.createdDate),
                                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                                ),
                                                              ),
                                                              Text(
                                                                "${Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? "(-" : "+"}${Constant.amountShow(amount: walletTransactionModel.amount.toString().replaceAll("-", ""))}${Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? ")" : ""}",
                                                                style: GoogleFonts.poppins(
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? Colors.red : Colors.green),
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            walletTransactionModel.note.toString(),
                                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w400),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: ButtonThem.buildButton(
                      context,
                title: "Recargar mi billetera".tr,
                      onPress: () {
                  Get.to(() => const RecargarScreen());
                      },
              ),
            ),
          );
        });
  }

  withdrawAmountBottomSheet(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        builder: (context) {
          final themeChange = Provider.of<DarkThemeProvider>(context);

          return StatefulBuilder(builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 25.0, bottom: 10),
                      child: Text(
                        "Withdraw".tr,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Container(
                        decoration: BoxDecoration(
                          color: themeChange.getThem() ? AppColors.darkContainerBackground : AppColors.containerBackground,
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: themeChange.getThem() ? AppColors.darkContainerBorder : AppColors.containerBorder, width: 0.5),
                          boxShadow: themeChange.getThem()
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2), // changes position of shadow
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    controller.bankDetailsModel.value.bankName.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.account_balance,
                                    size: 40,
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                controller.bankDetailsModel.value.accountNumber.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                controller.bankDetailsModel.value.holderName.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                controller.bankDetailsModel.value.branchName.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                controller.bankDetailsModel.value.otherInformation.toString(),
                                style: GoogleFonts.poppins(),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(
                      height: 20,
                    ),
                    RichText(
                      text: TextSpan(
                        text: "Amount to Withdraw".tr,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    TextFieldThem.buildTextFiled(context, hintText: 'Enter Amount'.tr, controller: controller.withdrawalAmountController.value),
                    const SizedBox(
                      height: 10,
                    ),
                    TextFieldThem.buildTextFiled(context, hintText: 'Notes'.tr, maxLine: 3, controller: controller.noteController.value),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ButtonThem.buildButton(
                          context,
                          title: "Withdrawal".tr,
                          onPress: () async {
                            if (double.parse(controller.driverUserModel.value.walletAmount.toString()) < double.parse(controller.withdrawalAmountController.value.text)) {
                              ShowToastDialog.showToast("Insufficient balance".tr);
                            } else if (double.parse(Constant.minimumAmountToWithdrawal) > double.parse(controller.withdrawalAmountController.value.text)) {
                              ShowToastDialog.showToast(
                                  "Withdraw amount must be greater or equal to ${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal.toString())}".tr);
                            } else {
                              ShowToastDialog.showLoader("Por favor espera".tr);
                              WithdrawModel withdrawModel = WithdrawModel();
                              withdrawModel.id = Constant.getUuid();
                              withdrawModel.userId = FireStoreUtils.getCurrentUid();
                              withdrawModel.paymentStatus = "pending";
                              withdrawModel.amount = controller.withdrawalAmountController.value.text;
                              withdrawModel.note = controller.noteController.value.text;
                              withdrawModel.createdDate = Timestamp.now();

                              await FireStoreUtils.updatedDriverWallet(amount: "-${controller.withdrawalAmountController.value.text}");

                              await FireStoreUtils.setWithdrawRequest(withdrawModel).then((value) {
                                controller.getUser();
                                ShowToastDialog.closeLoader();
                                ShowToastDialog.showToast("Request sent to admin".tr);
                                Get.back();
                              });
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }
}
