@isTest
private class MaintenanceRequestTest {
	@testSetup static void setup() {
        // Create one equip record with a 40 day maintenance cycle
        Product2 testEquip40 = new Product2(name='test',maintenance_cycle__c=40,replacement_part__c=true);
        insert testEquip40;
        
        // Create one equip record with a 50 day maintenance cycle
        Product2 testEquip50 = new Product2(name='test',maintenance_cycle__c=50,replacement_part__c=true);
        insert testEquip50;
        
        // Create one vehicle; the vehicle is not used for anything in these scenarios
        Vehicle__c testVehicle = new Vehicle__c(name='test');
        
        // Create 300 Cases with testEquip50, testVehicle
        // for the 'Repair' cases, create two Work Parts (one testEquip40 and one testEquip50)
        // all the Cases are created with Status='New'; we'll close them later
        // 140 are Type='Repair'; 140 are Type='Routine Maintenance'; 20 are Type='Mechanical' (to test non-creation of Cases)
        List<Case> testCases = new List<Case>();
        for (Integer i=0;i<140;i++) {
        	Case c1 = new Case(Subject='Test '+ i,Status='New',Type='Repair',Equipment__c=testEquip50.Id,Vehicle__c=testVehicle.Id,Origin='Web');
            Case c2 = new Case(Subject='Test '+ 140 + i,Status='New',Type='Routine Maintenance',Equipment__c=testEquip50.Id,Vehicle__c=testVehicle.Id,Origin='Web');
            testCases.add(c1);
            testCases.add(c2);
        }
        for (Integer i=280;i<300;i++){
            Case c3 = new Case(Subject='Test '+i,Status='New',Type='Mechanical',Origin='Web');
            testCases.add(c3);
        }
        insert testCases;
        
        List<Work_Part__c> testWorkParts = new List<Work_Part__c>();
        for (Case c: testCases) {
            if (c.Type == 'Repair') {
                testWorkParts.add(new Work_Part__c(Maintenance_Request__c=c.Id,Equipment__c=testEquip40.Id));
                testWorkParts.add(new Work_Part__c(Maintenance_Request__c=c.Id,Equipment__c=testEquip50.Id));
            }
        }
		insert testWorkParts;
    }
    
    @isTest static void testCaseUpdate() {
        // get the test cases
        List<Case> cases = new List<Case>([SELECT Id, Status FROM Case WHERE Subject LIKE 'Test%']);
        
        // close the cases
        for (Case c: cases) {
			c.Status = 'Closed';            
        }
        update cases;

        // 280 cases should have been updated; the 20 Type='Mechanical' should not have been updated
        List<Case> updatedCases = [SELECT Id, Parent.Type FROM Case 
                                   WHERE Subject = 'Routine Maintenance'
                                     AND (Parent.Type = 'Repair' OR Parent.Type = 'Routine Maintenance')];
        System.assertEquals(updatedCases.size(), 280);

        // 140 'Repair' cases should have Work Parts with a due date of today()+40
        // because the two Work Parts have cycle times of 40 and 50, respectively, and we use the MIN.
        // And there should be 280 Work Part clones attached to these cases
        Date due = Date.today().addDays(40);
        List<Case> repairCases = [SELECT Id, Parent.Type, Date_Due__c FROM Case
                                  WHERE Subject = 'Routine Maintenance'
                                    AND Parent.Type = 'Repair'
                                    AND Date_Due__c = :due];
        System.assertEquals(140, repairCases.size());
        
        // And there should be 280 Work Part clones attached to these cases
        List<Work_Part__c> workParts = [SELECT Id, Maintenance_Request__r.Subject, Maintenance_Request__r.Parent.Type 
                                        FROM Work_Part__c
                                        WHERE Maintenance_Request__r.Subject = 'Routine Maintenance'
                                                AND Maintenance_Request__r.Parent.Type = 'Repair'];
        System.assertEquals(280, workParts.size());

        // Finally, for the 140 'Routine Maintenance' parents, the cycle time should be using the 50 days from the related Equipment 
        due = Date.today().addDays(50);
        List<Case> rmCases = [SELECT Id, Parent.Type, Date_Due__c FROM Case
                                  WHERE Subject = 'Routine Maintenance'
                                    AND Parent.Type = 'Routine Maintenance'
                                    AND Date_Due__c = :due];
        System.assertEquals(140, rmCases.size());
    }
}