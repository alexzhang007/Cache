//////////////////////////////////////////////////////////////////////////////////////////
//Copyright (c) 2014 by Grision Technology Inc. (GTI), and Alex Zhang  
//All rights reserved. 
//
//The contents of this file should not be disclosed to third parties, copied or duplicated
//in any form, in whole or in part, without the prior permission of the author, founder of 
//GTI company.  
//////////////////////////////////////////////////////////////////////////////////////////

`define CACHE_LINE_W     9   // 64 Byte each line = 512Bit
`define CACHE_LINE_N     512
`define CACHE_DEPTH_W    8 
`define CACHE_DEPTH_N    256 

//Cache Address Tag info ram 
//*W - Width
//*R - Range
//*N - Number
`define CA_TAG_W      18
`define CA_TAG_R      31:14
`define CA_INDEX_N    256
`define CA_INDEX_W    8 
`define CA_INDEX_R    13:6
`define CA_BLOCK_W    4
`define CA_BLOCK_R    5:2
`define CA_BYTE_W     2
`define CA_BYTE_R     1:0

//Tag Ram Line 
`define TR_VALID_R    0:0
`define TR_DIRTY_R    1:1
`define TR_LRU_R      3:2 //4ways need 2 bits to record the relative time
`define TR_TAG_R      21:4
`define TR_LINE_N     22
`define TR_TAG_W      18
`define TR_LRU_W      2
`define TR_DIRTY_W    1
`define TR_VALID_W    1

//cache_controller.v
`define CACHE_ID  6'b10010

