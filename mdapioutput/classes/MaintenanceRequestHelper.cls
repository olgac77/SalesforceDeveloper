public class MaintenanceRequestHelper {
    
    public static void updateWorkOrders(List<Case> updatedCases, Map<Id,Case> oldCaseMap){
    
        // updatedCases <= Trigger.New
        // oldCaseMap <= Trigger.oldMap

        // we only need to create new Routine Maintenance cases if 
        // 1. the case has been updated to 'Closed'
        // 2. the case Type is either 'Repair' or 'Routine Maintenance'
        
        Set<Id> validCaseIds = new Set<Id>(); // holds all Case Ids that need to be touched
        for (Case c: updatedCases) {
            // continue only if the Case status has just been updated to 'Closed'
            if (oldCaseMap.get(c.Id).Status != 'Closed' && c.Status == 'Closed') {
                // continue only if the Type is 'Repair' or 'Routine Maintenance'
                if (c.Type == 'Repair' || c.Type == 'Routine Maintenance') {
                    // add the Case to the map of valid cases that need to be touched
                    validCaseIds.add(c.Id);
                }
            }
        } 

        // continue only if there's something to do
        if (!validCaseIds.isEmpty()) {
            // create a list to hold all the new Cases
            List<Case> newCases = new List<Case>();
            
            // create a map to hold all the old Case info including the associated Work Parts
            // we need the map because we're going to assign the old Case Id to be the parent of the new Case
            // we're going to use that ParentId to look up related Work Parts so that we can CLONE them to the new Case
            // NOTE: after the challenge, I looked online at some other solutions; the three that I found all said 
            //       to RE-PARENT the Work Parts to the new Case. Not only is there nothing in the scenario to suggest that this 
            //       is correct, but common sense suggests that you don't want to remove data (like these related records) from the 
            //       old, closed Cases. Seems like that would be an audit problem if anyone ever wanted to go back and see what
            //       was done for that old case.
            // NOTE: to clone (or re-parent) the Work Parts, we need to know from which closed Case the new Routine Maintenance Case
            //       was created. I used the standard 'Parent' field to hold that history. All the other solutions I saw created 
            //       a new custom field. In retrospect, the custom field might have been a better choice. The scenario is not 
            //       very detailed. A requirements discussion with the customer should elicit how the Parent field is or might be used. 
            Map<Id,Case> closedCaseMap = new Map<Id,Case>([SELECT Id, Vehicle__c, Equipment__c, Equipment__r.Maintenance_Cycle__c, 
                                                                  (SELECT Id, Equipment__c, Quantity__c FROM Work_Parts__r) 
                                                           FROM Case 
                                                           WHERE Id IN :validCaseIds]);
            
            // create a map to hold the minimum cycle time for each of the valid cases
            Map<Id, Decimal> maintCycleMap = new Map<Id, Decimal>();
            
            // use the MIN aggregate to get the minimum value of Maintenance_Cycle__c for each Case and map it to the Case ID
            AggregateResult[] results = [SELECT Maintenance_Request__c, MIN(Equipment__r.Maintenance_Cycle__c)cycle
           								 FROM Work_Part__c 
                                         WHERE Maintenance_Request__c IN :validCaseIds 
            							 GROUP BY Maintenance_Request__c];
		
		    // build the map; remember, the Case Id is for the old, closed case  
            for (AggregateResult ar : results) {
                maintCycleMap.put((Id) ar.get('Maintenance_Request__c'), (Decimal) ar.get('cycle') );
            }

            for (Case cc: closedCaseMap.values()){
                // create a new child Case; keep the Vehicle and Equipment fields from the parent case; the other fields are defaulted
                // all the other field assignments are per requirements
                Case nc = new Case (ParentId = cc.Id,
                                    Status = 'New',
                                    Subject = 'Routine Maintenance',
                                    Type = 'Routine Maintenance',
                                    Vehicle__c = cc.Vehicle__c,
                                    Equipment__c = cc.Equipment__c,
                                    Origin = 'Web',  // NOTE: Origin is required, but the valued was not specified; I used a standard value; a better solution would have been to create a new custom value
                                    Date_Reported__c = Date.today());

                // if there are no Work Parts, there won't be a minimum value to assign to the new Case
                // the req'ts don't specify what to do in this case; it seems reasonable to use the cycle from Equipment__c
                if (maintCycleMap.containsKey(cc.Id) ) {
                    nc.Date_Due__c = Date.today().addDays((Integer) maintCycleMap.get(cc.Id));
                } else {
                    nc.Date_Due__c = Date.today().addDays((Integer) cc.Equipment__r.Maintenance_Cycle__c);
                } 
                
                newCases.add(nc);
            }
            
            // insert the new Cases
            insert newCases;
            
            // clone the Work Parts and assign them to the new Case
            List<Work_Part__c> clonedWorkParts = new List<Work_Part__c>();
            for (Case nc: newCases) {
                // for each new Case, clone all the Work Parts from the parent case, and assign them to the new Case
                for (Work_Part__c wp: closedCaseMap.get(nc.ParentId).Work_Parts__r) {
                    Work_Part__c wpClone = wp.clone();
                    wpClone.Maintenance_Request__c = nc.Id;
                    clonedWorkParts.add(wpClone);
                }
            }
            
            // insert the cloned work parts
            insert clonedWorkParts;
        }
    }        
}