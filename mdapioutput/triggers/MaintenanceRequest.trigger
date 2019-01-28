trigger MaintenanceRequest on Case (before update, after update) {
    // all the logic is in the MaintenanceRequestHelper class

    // for the challenge the trigger was prepopulated with "before update" and "after update"
    // but we only want to update Cases after update 
    if ( Trigger.isAfter && Trigger.isUpdate ) {
        // for the challenge, the MaintenanceRequestHelper class was prepopulated with an 'updateWorkOrders' method
        MaintenanceRequestHelper.updateWorkOrders ( Trigger.New, Trigger.OldMap );
    }  
}