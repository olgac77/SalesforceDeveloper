@isTest
private class WarehouseCalloutServiceTest {
  // implement your mock callout test here

    // NOTE: still find CRON confusing; this is copied from https://trailhead.salesforce.com/en/content/learn/modules/asynchronous_apex/async_apex_scheduled 
    public static String CRON_EXP = '0 0 0 15 3 ? 2022';
	
    @isTest
    static void WarehouseEquipmentSync(){

        Test.startTest();

            // Set mock callout class 
            Test.setMock(HttpCalloutMock.class, new WarehouseCalloutServiceMock()); 
            
            WarehouseCalloutService.runWarehouseEquipmentSync();
            
        Test.stopTest();        
        
        // get the list of products inserted (should be 1)      
        List<Product2> updatedProds = [SELECT Replacement_Part__c, Cost__c, Current_Inventory__c, 
                                              Lifespan_Months__c, Maintenance_Cycle__c, Name FROM Product2];
        
        // the mock service returns 1 record
        System.assertEquals(1, updatedProds.size());
        
        // check to see that the returned values all match
        // NOTE: there should be a better way to do this so that the mock data defined in WarehouseCalloutServiceMock
        //       and the data checked here are always in sync
        for (Product2 p : updatedProds) {
            System.assertEquals(true, p.Replacement_Part__c);
            System.AssertEquals(5000, p.Cost__c);
            System.assertEquals(5, p.Current_Inventory__c);
            System.assertEquals(120, p.Lifespan_Months__c);
            System.assertEquals(365, p.Maintenance_Cycle__c);
            System.assertEquals('Generator 1000 kW', p.Name);
        }
    }

    @isTest
    static void warehouseSyncScheduleTest() {

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new WarehouseCalloutServiceMock()); 
            
            // schedule the job
            String jobId = System.schedule('WarehouseSyncTest', CRON_EXP, new WarehouseSyncSchedule());
            
            // get the current state and verify that it's pending
            CronTrigger cTId = [SELECT State FROM CronTrigger WHERE Id = :jobID];
            System.assertEquals('WAITING', String.valueOf(cTId.State));

        Test.stopTest();
    }
}