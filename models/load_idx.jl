function load_idx()
    #负荷索引
    ##===================================idx=========================##
    load_EquipmentID=1;#负荷设备ID
    ConectedID=2;#所在节点序号
    load_inservice=6;#相数
    load_kva=10;#最大需求指数
    load_pf=12;#连续额定容量
    load_type=18;#负载类型
    Pload_percent=19;#恒功率负载百分比
    return load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent
end