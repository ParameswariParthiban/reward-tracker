
@IsTest
private class SalesRecordTriggerHandlerTest {

    // Helper method to create a Member
    private static Member__c createMember() {
        Member__c member = new Member__c(
            Name = 'Test Member',
            Status__c = 'Active',
            Region__c = 'North'
        );

        insert member;
        return member;
    }


    // Helper method to create a Member Branch
    private static Member_Branch__c createBranch(
        Id memberId,
        String status,
        Date suspensionDate
    ) {
        Member_Branch__c branch = new Member_Branch__c(
            Name = 'Test Branch',
            Member__c = memberId,
            Branch_Status__c = status,
            Suspension_Date__c = suspensionDate
        );

        insert branch;
        return branch;
    }


    @IsTest
    static void testExcludedCategory() {

        Member__c member = createMember();

        Member_Branch__c branch =
            createBranch(member.Id, 'Active', null);

        Sales_Record__c sale = new Sales_Record__c(
            Member_Branch__c = branch.Id,
            Sale_Date__c = Date.newInstance(2026, 5, 15),
            Sale_Amount__c = 1000,
            Category__c = 'Excluded_Category',
            Is_Return__c = false,
            Registration_Date__c = Date.newInstance(2026, 5, 15)
        );

        Test.startTest();
        insert sale;
        Test.stopTest();

        System.assertEquals(true, sale.Excluded__c);
        System.assertEquals(
            'Excluded category',
            sale.Exclusion_Reason__c
        );
    }


    @IsTest
    static void testOnlineCategory() {

        Member__c member = createMember();

        Member_Branch__c branch =
            createBranch(member.Id, 'Active', null);

        Sales_Record__c sale = new Sales_Record__c(
            Member_Branch__c = branch.Id,
            Sale_Date__c = Date.newInstance(2026, 5, 15),
            Sale_Amount__c = 1000,
            Category__c = 'Online',
            Is_Return__c = false,
            Registration_Date__c = Date.newInstance(2026, 5, 15)
        );

        Test.startTest();
        insert sale;
        Test.stopTest();

        System.assertEquals(true, sale.Excluded__c);
        System.assertEquals(
            'Excluded category',
            sale.Exclusion_Reason__c
        );
    }


    @IsTest
    static void testReturnSale() {

        Member__c member = createMember();

        Member_Branch__c branch =
            createBranch(member.Id, 'Active', null);

        Sales_Record__c sale = new Sales_Record__c(
            Member_Branch__c = branch.Id,
            Sale_Date__c = Date.newInstance(2026, 5, 15),
            Sale_Amount__c = 1000,
            Category__c = 'Standard',
            Is_Return__c = true,
            Registration_Date__c = Date.newInstance(2026, 5, 15)
        );

        Test.startTest();
        insert sale;
        Test.stopTest();

        System.assertEquals(true, sale.Excluded__c);
        System.assertEquals(
            'Return',
            sale.Exclusion_Reason__c
        );
    }


    @IsTest
    static void testSuspendedBranch() {

        Member__c member = createMember();

        Date suspensionDate =
            Date.newInstance(2026, 5, 10);

        Member_Branch__c branch =
            createBranch(
                member.Id,
                'Suspended',
                suspensionDate
            );

        Sales_Record__c sale = new Sales_Record__c(
            Member_Branch__c = branch.Id,
            Sale_Date__c = Date.newInstance(2026, 5, 15),
            Sale_Amount__c = 1000,
            Category__c = 'Standard',
            Is_Return__c = false,
            Registration_Date__c = Date.newInstance(2026, 5, 15)
        );

        Test.startTest();
        insert sale;
        Test.stopTest();

        System.assertEquals(true, sale.Excluded__c);
        System.assertEquals(
            'Sale made after branch suspension',
            sale.Exclusion_Reason__c
        );
    }


    @IsTest
    static void testLateRegistration() {

        Member__c member = createMember();

        Member_Branch__c branch =
            createBranch(member.Id, 'Active', null);

        // Sale date is in Q1:
        // Q1 = Apr 1 - Jun 30
        Date saleDate =
            Date.newInstance(2026, 6, 20);

        // Quarter end = June 30
        // 14-day limit = July 14
        // July 15 is late
        Date registrationDate =
            Date.newInstance(2026, 7, 15);

        Sales_Record__c sale = new Sales_Record__c(
            Member_Branch__c = branch.Id,
            Sale_Date__c = saleDate,
            Sale_Amount__c = 1000,
            Category__c = 'Standard',
            Is_Return__c = false,
            Registration_Date__c = registrationDate
        );

        Test.startTest();
        insert sale;
        Test.stopTest();

        System.assertEquals(true, sale.Excluded__c);
        System.assertEquals(
            'Registration more than 14 days after quarter end',
            sale.Exclusion_Reason__c
        );
    }


    @IsTest
    static void testNormalSaleNotExcluded() {

        Member__c member = createMember();

        Member_Branch__c branch =
            createBranch(member.Id, 'Active', null);

        Sales_Record__c sale = new Sales_Record__c(
            Member_Branch__c = branch.Id,
            Sale_Date__c = Date.newInstance(2026, 5, 15),
            Sale_Amount__c = 1000,
            Category__c = 'Standard',
            Is_Return__c = false,
            Registration_Date__c = Date.newInstance(2026, 5, 20)
        );

        Test.startTest();
        insert sale;
        Test.stopTest();

        System.assertEquals(false, sale.Excluded__c);
        System.assertEquals(
            null,
            sale.Exclusion_Reason__c
        );
    }
}

