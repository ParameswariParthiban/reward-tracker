public class SalesRecordTriggerHandler {

    public static void handleBefore(
        List<Sales_Record__c> newRecords,
        Map<Id, Sales_Record__c> oldMap
    ) {

        // 1. Collect Member Branch IDs
        Set<Id> branchIds = new Set<Id>();

        for (Sales_Record__c sale : newRecords) {
            if (sale.Member_Branch__c != null) {
                branchIds.add(sale.Member_Branch__c);
            }
        }

        // 2. Query parent Member Branch records
        Map<Id, Member_Branch__c> branchMap =
            new Map<Id, Member_Branch__c>();

        if (!branchIds.isEmpty()) {
            branchMap = new Map<Id, Member_Branch__c>([
                SELECT Id,
                       Branch_Status__c,
                       Suspension_Date__c
                FROM Member_Branch__c
                WHERE Id IN :branchIds
            ]);
        }

        // 3. Check  conditions for each Sales_Record__c
        for (Sales_Record__c sale : newRecords) {

            sale.Excluded__c = false;
            sale.Exclusion_Reason__c = null;

            // Condition 1: Category
            if (sale.Category__c == 'Excluded_Category' ||
                sale.Category__c == 'Online') {

                sale.Excluded__c = true;
                sale.Exclusion_Reason__c =
                    'Excluded category';

            }

            // Condition 2: Return
            else if (sale.Is_Return__c == true) {

                sale.Excluded__c = true;
                sale.Exclusion_Reason__c =
                    'Return';

            }

            // Condition 3: Suspended branch
            else if (isSuspendedSale(sale, branchMap)) {

                sale.Excluded__c = true;
                sale.Exclusion_Reason__c =
                    'Sale made after branch suspension';

            }

            // Condition 4: Registration more than 14 days
            else if (isLateRegistration(sale)) {

                sale.Excluded__c = true;
                sale.Exclusion_Reason__c =
                    'Registration more than 14 days after quarter end';
            }
        }
    }


    private static Boolean isSuspendedSale(
        Sales_Record__c sale,
        Map<Id, Member_Branch__c> branchMap
    ) {

        if (sale.Member_Branch__c == null ||
            sale.Sale_Date__c == null) {
            return false;
        }

        Member_Branch__c branch =
            branchMap.get(sale.Member_Branch__c);

        if (branch == null) {
            return false;
        }

        return branch.Branch_Status__c == 'Suspended' &&
               branch.Suspension_Date__c != null &&
               sale.Sale_Date__c >= branch.Suspension_Date__c;
    }


    private static Boolean isLateRegistration(
        Sales_Record__c sale
    ) {

        if (sale.Sale_Date__c == null ||
            sale.Registration_Date__c == null) {
            return false;
        }

        Date quarterEnd =
            getQuarterEnd(sale.Sale_Date__c);

        Date allowedRegistrationDate =
            quarterEnd.addDays(14);

        return sale.Registration_Date__c >
               allowedRegistrationDate;
    }


    private static Date getQuarterEnd(Date saleDate) {

        Integer month = saleDate.month();
        Integer year = saleDate.year();

        if (month >= 4 && month <= 6) {
            return Date.newInstance(year, 6, 30);

        } else if (month >= 7 && month <= 9) {
            return Date.newInstance(year, 9, 30);

        } else if (month >= 10 && month <= 12) {
            return Date.newInstance(year, 12, 31);

        } else {
            return Date.newInstance(year, 3, 31);
        }
    }
}