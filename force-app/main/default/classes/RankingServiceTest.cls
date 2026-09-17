@IsTest
private class RankingServiceTest {

    @TestSetup
    static void createTestData() {

        Member__c alpha = new Member__c(
            Name = 'Test Alpha',
            Status__c = 'Active',
            Region__c = 'North'
        );

        Member__c beta = new Member__c(
            Name = 'Test Beta',
            Status__c = 'Active',
            Region__c = 'North'
        );

        Member__c gamma = new Member__c(
            Name = 'Test Gamma',
            Status__c = 'Active',
            Region__c = 'North'
        );

        insert new List<Member__c>{
            alpha,
            beta,
            gamma
        };

        insert new List<Quarterly_Score__c>{

            new Quarterly_Score__c(
                Member__c = alpha.Id,
                Quarter__c = 'Q1',
                Total_Sales_Value__c = 16000,
                Base_Reward__c = 500
            ),

            new Quarterly_Score__c(
                Member__c = beta.Id,
                Quarter__c = 'Q1',
                Total_Sales_Value__c = 12000,
                Base_Reward__c = 300
            ),

            new Quarterly_Score__c(
                Member__c = gamma.Id,
                Quarter__c = 'Q1',
                Total_Sales_Value__c = 16000,
                Base_Reward__c = 500
            )
        };
    }


    @IsTest
    static void testRankingAndTie() {

        List<Quarterly_Score__c> scores = [
            SELECT Id,
                   Member__c,
                   Member__r.Region__c,
                   Quarter__c,
                   Total_Sales_Value__c,
                   Base_Reward__c,
                   Topper_Reward__c,
                   Rank__c,
                   Is_Tie__c,
                   Manual_Rank_Override__c
            FROM Quarterly_Score__c
            WHERE Quarter__c = 'Q1'
        ];

        Test.startTest();

        RankingService.applyRanking(scores);

        Test.stopTest();

        Map<String, Quarterly_Score__c> scoreByMember =
            new Map<String, Quarterly_Score__c>();

        for (Quarterly_Score__c score : scores) {
            scoreByMember.put(
                score.Member__r.Name,
                score
            );
        }

        Quarterly_Score__c alpha =
            scoreByMember.get('Test Alpha');

        Quarterly_Score__c beta =
            scoreByMember.get('Test Beta');

        Quarterly_Score__c gamma =
            scoreByMember.get('Test Gamma');


        // Alpha and Gamma have equal sales
        System.assertEquals(
            true,
            alpha.Is_Tie__c
        );

        System.assertEquals(
            true,
            gamma.Is_Tie__c
        );

        System.assertEquals(
            null,
            alpha.Rank__c
        );

        System.assertEquals(
            null,
            gamma.Rank__c
        );


        // Beta has the next distinct position
        System.assertEquals(
            3,
            beta.Rank__c
        );

        // North threshold is 2,
        // so Beta does not receive topper reward.
        System.assertEquals(
            0,
            beta.Topper_Reward__c
        );
    }


    @IsTest
    static void testManualRankOverride() {

        Quarterly_Score__c alpha = [
            SELECT Id,
                   Member__c,
                   Member__r.Region__c,
                   Quarter__c,
                   Total_Sales_Value__c,
                   Base_Reward__c,
                   Topper_Reward__c,
                   Rank__c,
                   Is_Tie__c,
                   Manual_Rank_Override__c
            FROM Quarterly_Score__c
            WHERE Member__r.Name = 'Test Alpha'
            LIMIT 1
        ];

        alpha.Manual_Rank_Override__c = 1;
        update alpha;

        List<Quarterly_Score__c> scores = [
            SELECT Id,
                   Member__c,
                   Member__r.Region__c,
                   Quarter__c,
                   Total_Sales_Value__c,
                   Base_Reward__c,
                   Topper_Reward__c,
                   Rank__c,
                   Is_Tie__c,
                   Manual_Rank_Override__c
            FROM Quarterly_Score__c
            WHERE Quarter__c = 'Q1'
        ];

        Test.startTest();

        RankingService.applyRanking(scores);

        Test.stopTest();

        Quarterly_Score__c updatedAlpha;

        for (Quarterly_Score__c score : scores) {
            if (score.Member__r.Name == 'Test Alpha') {
                updatedAlpha = score;
                break;
            }
        }

        // Manual rank 1 is within North threshold 2.
        // Topper reward = 50% of 500 = 250.
        System.assertEquals(
            250,
            updatedAlpha.Topper_Reward__c
        );
    }
}