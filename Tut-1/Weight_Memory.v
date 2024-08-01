`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.02.2019 17:25:12
// Design Name: 
// Module Name: Weight_Memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "include.v"

//一个可以配置深度和宽度的寄存器，深度的定义同时决定着地址的位宽，宽度的定义和数据位宽理论上也应该相等（但是此处没有定义为一个参数？）
//使用方式是，给使能和地址 可以进行读数据和写数据
//可以选择是否使用一个二进制文件来初始化参数

module Weight_Memory #(parameter numWeight = 3, neuronNo=5, layerNo=1, addressWidth=10, dataWidth=16, weightFile="w_1_15.mif")//neuronNo=5, layerNo=1  这两个参数是干嘛用的？
    ( 
    input clk,//时钟
    input wen,//写使能
    input ren,//读使能
    input [addressWidth-1:0] wadd,//写地址
    input [addressWidth-1:0] radd,//读地址，addressWidth是地址位宽
    input [dataWidth-1:0] win,//权重输入，dataWidth表示数据位宽
    output reg [dataWidth-1:0] wout);//权重输出
    
    reg [dataWidth-1:0] mem [numWeight-1:0];//定义权重寄存器的位宽和深度，位宽和数据位宽什么联系？？

    //$readmemb是一个系统函数，从指定的二进制文件中按字节读取二进制数据，并存储到给定第寄存器中
    //只能在仿真中使用
    //此处的b表示要读取的文件是二进制文件

    `ifdef pretrained//翻译是预训练的，表示如果定义了预训练变量，就执行下面代码
        initial
		begin
	        $readmemb(weightFile, mem);//weightFile表示存放权重的文件，是一个二进制文件
	    end
	`else
		always @(posedge clk)
		begin
			if (wen)
			begin
				mem[wadd] <= win;//写数据，时钟到来且使能开启，则给定的写地址所在的空间被替换为wim
			end
		end 
    `endif
    
    always @(posedge clk)
    begin
        if (ren)
        begin
            wout <= mem[radd];//读数据
        end
    end 
endmodule
