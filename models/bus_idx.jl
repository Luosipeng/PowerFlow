function bus_idx()
    #节点母线索引
    ##===================================idx=========================##
    EquipmentID=2;      #序号
    Voltage=5;          #电压
    Initial_Voltage=7;  #潮流初始值（标幺值）
    In_Service=3;       #是否投入工作
    Bus_Type=8;        #节点类型，7：slack节点；0：PQ节点；2：PV节点
    #TODO:

    return EquipmentID,Voltage,Initial_Voltage,In_Service,Bus_Type
end