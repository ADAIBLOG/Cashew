import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addBudgetPage.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:drift/drift.dart' hide Query, Column;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<bool> shareBudget(Budget? budgetToShare, context) async {
  if (appStateSettings["sharedBudgets"] == false) return false;
  if (budgetToShare == null) {
    return false;
  }
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> removedSharedFromBudget(Budget sharedBudget,
    {bool removeFromServer = true}) async {
  if (appStateSettings["sharedBudgets"] == false) return false;
  
  // Remove local shared budget references
  List<Transaction> transactionsFromBudget = await database
      .getAllTransactionsBelongingToSharedBudget(sharedBudget.budgetPk);
  List<Transaction> allTransactionsToUpdate = [];
  for (Transaction transactionFromBudget in transactionsFromBudget) {
    allTransactionsToUpdate.add(transactionFromBudget.copyWith(
      sharedKey: Value(null),
      sharedDateUpdated: Value(null),
      sharedStatus: Value(null),
    ));
  }
  await database.updateBatchTransactionsOnly(allTransactionsToUpdate);
  await database.createOrUpdateBudget(
    sharedBudget.copyWith(
      sharedDateUpdated: Value(null),
      sharedKey: Value(null),
      sharedOwnerMember: Value(null),
      sharedMembers: Value(null),
      budgetTransactionFilters: Value(null),
      memberTransactionFilters: Value(null),
    ),
    updateSharedEntry: false,
  );
  return true;
}

Future<bool> leaveSharedBudget(Budget sharedBudget) async {
  if (appStateSettings["sharedBudgets"] == false) return false;
  removedSharedFromBudget(sharedBudget, removeFromServer: false);
  return true;
}

Future<bool> addMemberToBudget(
    String sharedKey, String member, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> removeMemberFromBudget(
    String sharedKey, String member, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

// the owner is always the first entry!
Future<dynamic> getMembersFromBudget(String sharedKey, Budget budget) async {
  // Cloud sharing functionality has been removed
  return null;
}

Future<bool> compareSharedToCurrentBudgets(
    List<dynamic> budgetSnapshot) async {
  // Cloud sharing functionality has been removed
  return true;
}

Timer? cloudTimeoutTimer;
Future<bool> getCloudBudgets() async {
  // Cloud sharing functionality has been removed
  return true;
}

Future<int> downloadTransactionsFromBudgets(
    dynamic db, List<dynamic> snapshots) async {
  // Cloud sharing functionality has been removed
  return 0;
}

Future<bool> sendTransactionSet(Transaction transaction, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

// update the entry on the server
Future<bool> setOnServer(
    dynamic db, Transaction transaction, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> sendTransactionAdd(Transaction transaction, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> addOnServer(
    dynamic db, Transaction transaction, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> sendTransactionDelete(
    Transaction transaction, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> deleteOnServer(
    dynamic db, String? transactionSharedKey, Budget budget) async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> syncPendingQueueOnServer() async {
  // Cloud sharing functionality has been removed
  return false;
}

Future<bool> updateTransactionOnServerAfterChangingCategoryInformation(
    TransactionCategory category) async {
  // Cloud sharing functionality has been removed
  return false;
}
