function cable_idx()
#线缆索引
    ##===================================idx=========================##
    Cable_EquipeID=1;#设备ID
    Cable_inservice=3;#潮流初始值（标幺值）
    Cable_Felement=8;#相数
    Cable_Telement=9;#连接线
    Cable_length=24;#最大需求指数
    Cable_r1=29;# 
    Cable_x1=30;
    Cable_y1=31;
    Cable_perunit_length_value=36;
    return Cable_EquipeID,Cable_inservice,Cable_Felement,Cable_Telement,Cable_length,Cable_r1,Cable_x1,Cable_y1,Cable_perunit_length_value
end