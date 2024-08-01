`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.11.2018 17:11:05
// Design Name: 
// Module Name: neuron
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
//`define DEBUG
`include "include.v"

//layerNo=0,neuronNo=0,numWeight=784,dataWidth=16,weightFile=""这四个参数是与权重寄存器相关的







//该模板表示的是一层神经元，一层神经元有两个标识数值，用于区分其他神经元,layerNo=0,neuronNo=0

module neuron #(parameter layerNo=0,neuronNo=0,numWeight=784,dataWidth=16,sigmoidSize=5,weightIntWidth=1,actType="relu",biasFile="",weightFile="")(
    input           clk,
    input           rst,

    input [dataWidth-1:0]    myinput,//输入的向量，即用于与权重相乘的输入值
    input           myinputValid,//输入值有效信号
    input           weightValid,//翻译过来数权重有效信号，作为权重载入时的其中一个判断条件
    input           biasValid,
    input [31:0]    weightValue,//载入权重时，作为权重值的输入，将被赋给w_in
    input [31:0]    biasValue,

    input [31:0]    config_layer_num,//等于layerNo时作为权重载入时的其中一个判断条件
    input [31:0]    config_neuron_num,//等于neuronNo时作为权重载入时的其中一个判断条件

    output[dataWidth-1:0]    out,//神经元的输出
    output reg      outvalid  //用于显示神经原的输出的信号？？ 
    );

//地址直接由寄存器的深度的log2得到 
    parameter addressWidth = $clog2(numWeight);

//权重寄存器的例化用到的中间变量
    reg         wen;
    wire        ren;
    reg [addressWidth-1:0] w_addr;
    reg [addressWidth:0]   r_addr;//read address has to reach until numWeight hence width is 1 bit more
    reg [dataWidth-1:0]  w_in;
    wire [dataWidth-1:0] w_out;

//计算中间变量
    reg [2*dataWidth-1:0]  mul;//表示权重与神经元输入的乘积
    reg [2*dataWidth-1:0]  sum;//表示权重与神经元输入的乘积的累加结果


    reg [2*dataWidth-1:0]  bias;//表示偏置
    








    reg [31:0]    biasReg[0:0];
    reg         weight_valid;
    reg         mult_valid;
    wire        mux_valid;
    reg         sigValid; 



//中间变量
    wire [2*dataWidth:0] comboAdd;//sum与乘积相加
    wire [2*dataWidth:0] BiasAdd;//sum与偏置相加



    reg  [dataWidth-1:0] myinputd;//用寄存器存一下神经元输入



    reg muxValid_d;
    reg muxValid_f;
    reg addr=0;//用于偏置的加载











   //Loading weight values into the memory
   //将权重寄存器例化时，数据输入的方式规定好
    always @(posedge clk)
    begin
        if(rst)
        begin
            w_addr <= {addressWidth{1'b1}};//重置时，地址设为全1，这样加一后变为全零，但是会在最后一个位置先存放数据，是因为要考虑延迟吗？？
            wen <=0;
        end
        else if(weightValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
        begin
            w_in <= weightValue;
            w_addr <= w_addr + 1;//存完一个数据后地址要加一，才能存储下个数据
            wen <= 1;
        end
        else
            wen <= 0;
    end












    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;//作为一个累加器使用，实现神经元输入和权重乘积的累加
    assign BiasAdd = bias + sum;//将累加结果加上偏置
    assign ren = myinputValid;
    





//偏置加载
    `ifdef pretrained
        initial
        begin
            $readmemb(biasFile,biasReg);
        end
        always @(posedge clk)
        begin
            bias <= {biasReg[addr][dataWidth-1:0],{dataWidth{1'b0}}};
        end
    `else
        always @(posedge clk)
        begin
            if(biasValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
            begin
                bias <= {biasValue[dataWidth-1:0],{dataWidth{1'b0}}};
            end
        end
    `endif
    












//控制读地址的值的改变，rst=1的下一个高电平到来时，r_addr开始每个时钟加一
//输入一有效，就开始读权重
    always @(posedge clk)
    begin
        if(rst|outvalid)
            r_addr <= 0;
        else if(myinputValid)
            r_addr <= r_addr + 1;
    end
    














//$signed是一个系统任务，它用于将一个表达式强制转换为有符号数
//每个时钟到来，mul都等于权重与神经元输入的乘积
    always @(posedge clk)
    begin
        mul  <= $signed(myinputd) * $signed(w_out);
    end
    




    
    
    always @(posedge clk)
    begin
        if(rst|outvalid)//表示累加到最后一个乘积时，要加上最后的偏置，需要有一些判断条件来识别是否到达最后一个神经元累加
            sum <= 0;
        else if((r_addr == numWeight) & muxValid_f)
        begin
            if(!bias[2*dataWidth-1] &!sum[2*dataWidth-1] & BiasAdd[2*dataWidth-1]) //If bias and sum are positive and after adding bias to sum, if sign bit becomes 1, saturate
            begin
                sum[2*dataWidth-1] <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
            end
            else if(bias[2*dataWidth-1] & sum[2*dataWidth-1] &  !BiasAdd[2*dataWidth-1]) //If bias and sum are negative and after addition if sign bit is 0, saturate
            begin
                sum[2*dataWidth-1] <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end
            else
                sum <= BiasAdd; 
        end
        else if(mux_valid)//代表将权重与神经元输入的乘积不段累加的过程，此时要识别出整数溢出和负数溢出，溢出时将其赋为最大值
        begin
            if(!mul[2*dataWidth-1] & !sum[2*dataWidth-1] & comboAdd[2*dataWidth-1])
            begin
                sum[2*dataWidth-1] <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
            end
            else if(mul[2*dataWidth-1] & sum[2*dataWidth-1] & !comboAdd[2*dataWidth-1])
            begin
                sum[2*dataWidth-1] <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end
            else
                sum <= comboAdd; 
        end
    end
    






    //一些值的传递
    always @(posedge clk)
    begin
        myinputd <= myinput;
        weight_valid <= myinputValid;
        mult_valid <= weight_valid;


        sigValid <= ((r_addr == numWeight) & muxValid_f) ? 1'b1 : 1'b0;
        outvalid <= sigValid;


        muxValid_d <= mux_valid;
        muxValid_f <= !mux_valid & muxValid_d;
    end
    







   //对权重寄存器的例化 
    //Instantiation of Memory for Weights
    Weight_Memory #(.numWeight(numWeight),.neuronNo(neuronNo),.layerNo(layerNo),.addressWidth(addressWidth),.dataWidth(dataWidth),.weightFile(weightFile)) WM(
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .wadd(w_addr),
        .radd(r_addr),
        .win(w_in),
        .wout(w_out)
    );









    generate
        if(actType == "sigmoid")
        begin:siginst
        //Instantiation of ROM for sigmoid
            Sig_ROM #(.inWidth(sigmoidSize),.dataWidth(dataWidth)) s1(
            .clk(clk),
            .x(sum[2*dataWidth-1-:sigmoidSize]),
            .out(out)
        );
        end
        else
        begin:ReLUinst
            ReLU #(.dataWidth(dataWidth),.weightIntWidth(weightIntWidth)) s1 (
            .clk(clk),
            .x(sum),
            .out(out)
        );
        end
    endgenerate

    `ifdef DEBUG
    always @(posedge clk)
    begin
        if(outvalid)
            $display(neuronNo,,,,"%b",out);
    end
    `endif
endmodule
