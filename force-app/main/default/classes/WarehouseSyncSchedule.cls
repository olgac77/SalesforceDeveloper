// NOTE: I'm still not clear on public vs global; the Schedulable examples on developer.salesforce.com all use global
global class WarehouseSyncSchedule implements Schedulable {
    global void execute(SchedulableContext ctx) {
        WarehouseCalloutService.runWarehouseEquipmentSync();
    }
}