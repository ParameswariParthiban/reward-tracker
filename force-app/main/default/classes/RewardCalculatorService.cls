public class RewardCalculatorService {

    // BR-4: Find the reward amount based on total sales
    public static Decimal calculateBaseReward(Decimal totalSales) {

        if (totalSales == null || totalSales <= 0) {
            return 0;
        }

        List<Reward_Slab__mdt> slabs = [
            SELECT Min_Value__c,
                   Max_Value__c,
                   Reward_Amount__c
            FROM Reward_Slab__mdt
            ORDER BY Min_Value__c DESC
        ];

        for (Reward_Slab__mdt slab : slabs) {

            Boolean meetsMinimum =
                totalSales >= slab.Min_Value__c;

            Boolean belowMaximum =
                slab.Max_Value__c == null ||
                totalSales <= slab.Max_Value__c;

            if (meetsMinimum && belowMaximum) {
                return slab.Reward_Amount__c;
            }
        }

        return 0;
    }
}