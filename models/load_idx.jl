function load_idx()
    #负荷索引
    ##===================================idx=========================##
    load_EquipmentID=2;#负荷设备ID
    ConectedID=5;#所在节点序号
    load_inservice=3;#相数
    load_kva=7;
    load_pf=8;#连续额定容量
    load_type=4;#负载类型
    Pload_percent=9;#恒功率负载百分比
    return load_EquipmentID,ConectedID,load_inservice,load_kva,load_pf,load_type,Pload_percent
end