public class RankingService {

    public static void applyRanking(
        List<Quarterly_Score__c> scores
    ) {

        if (scores == null || scores.isEmpty()) {
            return;
        }

        // Get the lowest reward slab minimum
        Reward_Slab__mdt lowestSlab = [
            SELECT Min_Value__c
            FROM Reward_Slab__mdt
            ORDER BY Min_Value__c ASC
            LIMIT 1
        ];

        Decimal minimumSales = lowestSlab.Min_Value__c;

        // Get regional ranking thresholds
        Map<String, Decimal> regionThresholdMap =
            new Map<String, Decimal>();

        for (Region_Threshold__mdt config : [
            SELECT Region__c, Max_Rank__c
            FROM Region_Threshold__mdt
        ]) {
            regionThresholdMap.put(
                config.Region__c,
                config.Max_Rank__c
            );
        }

        // Group scores by region
        Map<String, List<Quarterly_Score__c>> regionScores =
            new Map<String, List<Quarterly_Score__c>>();

        for (Quarterly_Score__c score : scores) {

            score.Rank__c = null;
            score.Is_Tie__c = false;
            score.Topper_Reward__c = 0;

            if (score.Total_Sales_Value__c == null ||
                score.Total_Sales_Value__c < minimumSales) {
                continue;
            }

            String region = score.Member__r.Region__c;

            if (!regionScores.containsKey(region)) {
                regionScores.put(
                    region,
                    new List<Quarterly_Score__c>()
                );
            }

            regionScores.get(region).add(score);
        }

        // Process each region
        for (String region : regionScores.keySet()) {

            List<Quarterly_Score__c> regionalScores =
                regionScores.get(region);

            // Sort highest sales first
            regionalScores.sort(new ScoreComparator());

            Decimal previousSales = null;
            Integer position = 0;
            Integer currentRank = 0;

            for (Quarterly_Score__c score : regionalScores) {

                position++;

                Decimal currentSales =
                    score.Total_Sales_Value__c;

                if (previousSales == null ||
                    currentSales != previousSales) {

                    currentRank = position;
                }

                // Tie
                Integer sameSalesCount = 0;

                for (Quarterly_Score__c otherScore : regionalScores) {
                    if (otherScore.Total_Sales_Value__c ==
                        currentSales) {
                        sameSalesCount++;
                    }
                }

                if (sameSalesCount > 1) {
                    score.Is_Tie__c = true;
                    score.Rank__c = null;
                } else {
                    score.Is_Tie__c = false;
                    score.Rank__c = currentRank;
                }

                previousSales = currentSales;
            }

            // Apply topper reward
            Decimal maxRank = regionThresholdMap.get(region);

            for (Quarterly_Score__c score : regionalScores) {

                Integer effectiveRank;

                if (score.Manual_Rank_Override__c != null) {
                    effectiveRank =
                        Integer.valueOf(
                            score.Manual_Rank_Override__c
                        );
                } else {
                    effectiveRank = score.Rank__c == null
                        ? null
                        : Integer.valueOf(score.Rank__c);
                }

                if (effectiveRank != null &&
                    maxRank != null &&
                    effectiveRank <= maxRank) {

                    score.Topper_Reward__c =
                        score.Base_Reward__c * 0.50;
                }
            }
        }

        update scores;
    }


    public class ScoreComparator
        implements Comparator<Quarterly_Score__c> {

        public Integer compare(
            Quarterly_Score__c a,
            Quarterly_Score__c b
        ) {

            if (a.Total_Sales_Value__c ==
                b.Total_Sales_Value__c) {
                return 0;
            }

            return a.Total_Sales_Value__c >
                   b.Total_Sales_Value__c
                ? -1
                : 1;
        }
    }
}