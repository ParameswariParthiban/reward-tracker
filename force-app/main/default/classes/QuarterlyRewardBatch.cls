public class QuarterlyRewardBatch implements Database.Batchable<SObject> {

    private String quarter;

    public QuarterlyRewardBatch(String quarter) {
        this.quarter = quarter;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id, Status__c, Region__c
            FROM Member__c
            WHERE Status__c = 'Active'
        ]);
    }

    public void execute(
        Database.BatchableContext bc,
        List<SObject> scope
    ) {

        List<Member__c> members = new List<Member__c>();

        for (SObject record : scope) {
            members.add((Member__c) record);
        }

        // BR-1: Only Active members are eligible
        List<Member__c> eligibleMembers = new List<Member__c>();

        for (Member__c member : members) {
            if (EligibilityService.isEligible(member)) {
                eligibleMembers.add(member);
            }
        }

        if (eligibleMembers.isEmpty()) {
            return;
        }

        Set<Id> memberIds = new Set<Id>();

        for (Member__c member : eligibleMembers) {
            memberIds.add(member.Id);
        }

        /*
         * BR-3:
         * Aggregate non-excluded sales by Member for the given quarter.
         *
         * Sales_Record__c
         *      ↓
         * Member_Branch__c
         *      ↓
         * Member__c
         */

        List<AggregateResult> salesResults = [
            SELECT
                Member_Branch__r.Member__c memberId,
                SUM(Sale_Amount__c) totalSales
            FROM Sales_Record__c
            WHERE Excluded__c = false
            AND Member_Branch__r.Member__c IN :memberIds
            AND Sale_Date__c != null
            GROUP BY Member_Branch__r.Member__c
        ];

        Map<Id, Decimal> memberSalesMap = new Map<Id, Decimal>();

        for (AggregateResult result : salesResults) {

            Id memberId = (Id) result.get('memberId');
            Decimal totalSales = (Decimal) result.get('totalSales');

            memberSalesMap.put(memberId, totalSales);
        }

        /*
         * Create/update Quarterly Score records.
         */

        Map<Id, Quarterly_Score__c> existingScores =
            new Map<Id, Quarterly_Score__c>();

        for (Quarterly_Score__c score : [
            SELECT Id,
                   Member__c,
                   Quarter__c,
                   Total_Sales_Value__c
            FROM Quarterly_Score__c
            WHERE Member__c IN :memberIds
            AND Quarter__c = :quarter
        ]) {
            existingScores.put(score.Member__c, score);
        }

        List<Quarterly_Score__c> scoresToSave =
            new List<Quarterly_Score__c>();

        for (Member__c member : eligibleMembers) {

            Decimal totalSales = memberSalesMap.containsKey(member.Id)
                ? memberSalesMap.get(member.Id)
                : 0;

            Quarterly_Score__c score;

            if (existingScores.containsKey(member.Id)) {
                score = existingScores.get(member.Id);
            } else {
                score = new Quarterly_Score__c();
                score.Member__c = member.Id;
                score.Quarter__c = quarter;
            }

            score.Total_Sales_Value__c = totalSales;

            scoresToSave.add(score);
        }

        if (!scoresToSave.isEmpty()) {
            upsert scoresToSave;
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Later we can call RankingService here.
    }
}