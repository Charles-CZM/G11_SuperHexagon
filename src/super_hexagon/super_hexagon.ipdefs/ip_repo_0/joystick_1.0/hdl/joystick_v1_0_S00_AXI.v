
`timescale 1 ns / 1 ps

	module joystick_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY,
		
		input wire MISO,
		          
        output wire MOSI,
        
        output wire SSout,
        
        output wire SCLK
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 2;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 6
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	        end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      //slv_reg1 <= 0;
	      //slv_reg2 <= 0;
	      //slv_reg3 <= 0;
	     // slv_reg4 <= 0;
	      //slv_reg5 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          3'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                //slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	               // slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                //slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h4:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                //slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          3'h5:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                //slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                      slv_reg4 <= slv_reg4;
	                      slv_reg5 <= slv_reg5;
	                    end
	        endcase
	      end
	  end
	end    

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        3'h0   : reg_data_out <= slv_reg0;
	        3'h1   : reg_data_out <= slv_reg1;
	        3'h2   : reg_data_out <= slv_reg2;
	        3'h3   : reg_data_out <= slv_reg3;
	        3'h4   : reg_data_out <= slv_reg4;
	        3'h5   : reg_data_out <= slv_reg5;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	//clock for joystick
	always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rdata  <= 0;
        end 
      else
        begin    
          // When there is a valid read address (S_AXI_ARVALID) with 
          // acceptance of read address by the slave (axi_arready), 
          // output the read dada 
          if (slv_reg_rden)
            begin
              axi_rdata <= reg_data_out;     // register read data
            end   
        end
    end    

	// Add user logic here
	
    //slv0: ctrReg+input
        //slv1: button click input
        //slv2 - 3: x axis input
        //slv4 - 5: y axis input
        
        
    
    //clock for joystick
    reg CLKOUT = 1'b1;
    parameter cntEndVal = 10'b1011101110;
    reg [9:0] clkCount = 10'b0000000000;
    
    always @(posedge S_AXI_ACLK) 
    begin
        if(S_AXI_ARESETN == 1'b0) 
        begin
            CLKOUT <= 1'b0;
            clkCount <= 10'b0000000000;
        end
        else 
        begin
            if(clkCount == cntEndVal) 
            begin
                CLKOUT <= ~CLKOUT;
                clkCount <= 10'b0000000000;
            end
            else 
            begin
                clkCount <= clkCount + 1'b1;
            end
        end
    end
    //clock end
    
    //wires
    reg BUSY;
    wire sndRec;
    wire [7:0] RxData;
    wire [7:0] DIN;
    
    assign DIN[7:0]=slv_reg0[8:1];
    assign sndRec = slv_reg0[0];
    // Control State Machine
    // Output wires and registers
    reg SS = 1'b1;
    reg getByte = 1'b0;
    reg [7:0] sndData = 8'h00;
    // FSM States
    parameter [2:0] Idle = 3'd0,
                Init = 3'd1,
                Wait = 3'd2,
                Check = 3'd3,
                Done = 3'd4;               
    // Present State
    reg [2:0] pState = Idle;
    reg [2:0] byteCnt = 3'd0;                    // Number bits read/written
    parameter byteEndVal = 3'd5;                // Number of bytes to send/receive
    reg [39:0] tmpSR = 40'h0000000000;        // Temporary shift register to
                                          // accumulate all five data bytes
                                          
    assign SSout = SS;
//-----------------------------------------------------------------------------------------------------------                                                                    
    
    always @(negedge CLKOUT) 
    begin
        if(S_AXI_ARESETN == 1'b0) 
        begin
            // Reest everything
            SS <= 1'b1;
            getByte <= 1'b0;
            sndData <= 8'h00;
            tmpSR <= 40'h0000000000;
            slv_reg1 <= 8'h00;
            slv_reg2 <= 8'h00;
            slv_reg3 <= 8'h00;
            slv_reg4 <= 8'h00;
            slv_reg5 <= 8'h00;
            byteCnt <= 3'd0;
            pState <= Idle;
        end
        else 
        begin
            case(pState)
            // Idle
            Idle : 
            begin
                SS <= 1'b1;                                // Disable slave
                getByte <= 1'b0;                        // Do not request data
                sndData <= 8'h00;                        // Clear data to be sent
                tmpSR <= 40'h0000000000;            // Clear temporary data
                slv_reg1 <= slv_reg1; 
                slv_reg2 <= slv_reg2;
                slv_reg3 <= slv_reg3;
                slv_reg4 <= slv_reg4;
                slv_reg5 <= slv_reg5;                       // Retain output data
                byteCnt <= 3'd0;                        // Clear byte count
                // When send receive signal received begin data transmission
                if(sndRec == 1'b1) 
                begin
                    pState <= Init;
                end
                else 
                begin
                    pState <= Idle;
                end        
            end
            // Init
            Init : 
            begin                                
                SS <= 1'b0;                                // Enable slave
                getByte <= 1'b1;                        // Initialize data transfer
                sndData <= DIN;                        // Store input data to be sent
                tmpSR <= tmpSR;                        // Retain temporary data
                slv_reg1 <= slv_reg1; 
                slv_reg2 <= slv_reg2;
                slv_reg3 <= slv_reg3;
                slv_reg4 <= slv_reg4;
                slv_reg5 <= slv_reg5;                            // Retain output data                                    
                if(BUSY == 1'b1)
                begin
                    pState <= Wait;
                    byteCnt <= byteCnt + 1'b1;    // Count
                end
                else 
                begin
                    pState <= Init;
                end                                        
            end
            // Wait
            Wait : 
            begin
                SS <= 1'b0;                                // Enable slave
                getByte <= 1'b0;                        // Data request already in progress
                sndData <= sndData;                    // Retain input data to send
                tmpSR <= tmpSR;                        // Retain temporary data
                slv_reg1 <= slv_reg1; 
                slv_reg2 <= slv_reg2;
                slv_reg3 <= slv_reg3;
                slv_reg4 <= slv_reg4;
                slv_reg5 <= slv_reg5;                           // Retain output data
                byteCnt <= byteCnt;                    // Count                                        
                // Finished reading byte so grab data
                if(BUSY == 1'b0) 
                begin
                    pState <= Check;
                end
                // Data transmission is not finished
                else 
                begin
                    pState <= Wait;
                end
            end
            // Check
            Check : 
            begin
                SS <= 1'b0;                                // Enable slave
                getByte <= 1'b0;                        // Do not request data
                sndData <= sndData;                    // Retain input data to send
                tmpSR <= {tmpSR[31:0], RxData};    // Store byte just read
                slv_reg1 <= slv_reg1; 
                slv_reg2 <= slv_reg2;
                slv_reg3 <= slv_reg3;
                slv_reg4 <= slv_reg4;
                slv_reg5 <= slv_reg5;                          // Retain output data
                byteCnt <= byteCnt;                    // Do not count
                // Finished reading bytes so done
                if(byteCnt == 3'd5) 
                begin
                    pState <= Done;
                end
                // Have not sent/received enough bytes
                else 
                begin
                    pState <= Init;
                end
            end
            // Done
            Done : 
            begin
                SS <= 1'b1;                            // Disable slave
                getByte <= 1'b0;                    // Do not request data
                sndData <= 8'h00;                    // Clear input
                tmpSR <= tmpSR;                    // Retain temporary data
                slv_reg1 <= tmpSR[7:0]; 
                slv_reg2 <= tmpSR[15:8];
                slv_reg3 <= tmpSR[23:16];
                slv_reg4 <= tmpSR[31:24];
                slv_reg5 <= tmpSR[39:32];        // Update output data
                byteCnt <= byteCnt;                // Do not count                                        
                // Wait for external sndRec signal to be de-asserted
                if(sndRec == 1'b0) 
                begin
                    pState <= Idle;
                end
                else 
                begin
                    pState <= Done;
                end
            end
            // Default State
            default : 
                pState <= Idle;
            endcase
        end
    end
    // Control State Machine End
    
    //Interface State Machine
    // FSM States
    parameter [1:0] Idle2 = 2'd0,
                Init2 = 2'd1,
                RxTx2 = 2'd2,
                Done2 = 2'd3;    
    reg [4:0] bitCount;                            // Number bits read/written
    reg [7:0] rSR = 8'h00;                        // Read shift register
    reg [7:0] wSR = 8'h00;                        // Write shift register
    reg [1:0] pState2 = Idle2;                    // Present state    
    reg CE = 0;                                        // Clock enable, controls serial
    // clock signal sent to slave
    // Serial clock output, allow if clock enable asserted
    assign SCLK = (CE == 1'b1) ? CLKOUT : 1'b0;
    // Master out slave in, value always stored in MSB of write shift register
    assign MOSI = wSR[7];
    // Connect data output bus to read shift register
    assign RxData = rSR;    
    //-------------------------------------
    //             Write Shift Register
    //     slave reads on rising edges,
    // change output data on falling edges
    //-------------------------------------
    always @(negedge CLKOUT)
    begin
        if(S_AXI_ARESETN == 1'b0) 
        begin
            wSR <= 8'h00;
        end
        else 
        begin
        // Enable shift during RxTx state only
            case(pState2)
                Idle2 : 
                begin
                    wSR <= sndData;
                end
    
                Init2 : 
                begin
                    wSR <= wSR;
                end
    
                RxTx2 : 
                begin
                    if(CE == 1'b1) 
                    begin
                        wSR <= {wSR[6:0], 1'b0};
                    end
                end
    
                Done2 : 
                begin
                    wSR <= wSR;
                end
            endcase
        end
    end    
    //-------------------------------------
    //             Read Shift Register
    //     master reads on rising edges,
    // slave changes data on falling edges
    //-------------------------------------
    always @(posedge CLKOUT) begin
        if(S_AXI_ARESETN == 1'b0) begin
            rSR <= 8'h00;
        end
        else begin
        // Enable shift during RxTx state only
            case(pState2)
                Idle2 : begin
                    rSR <= rSR;
                end    
                Init2 : begin
                    rSR <= rSR;
                end   
                RxTx2 : begin
                    if(CE == 1'b1) begin
                        rSR <= {rSR[6:0], MISO};
                    end
                end   
                Done2 : begin
                    rSR <= rSR;
                end
            endcase
        end
    end    
    //------------------------------
    //           SPI Mode 0 FSM
    //------------------------------
    always @(negedge CLKOUT) begin    
        // Reset button pressed
        if(S_AXI_ARESETN == 1'b0) begin
            CE <= 1'b0;                // Disable serial clock
            BUSY <= 1'b0;            // Not busy in Idle state
            bitCount <= 4'h0;        // Clear #bits read/written
            pState2 <= Idle2;        // Go back to Idle state
        end
        else begin
            case (pState2)  
                // Idle
                Idle2 : begin   
                    CE <= 1'b0;                // Disable serial clock
                    BUSY <= 1'b0;            // Not busy in Idle state
                    bitCount <= 4'd0;        // Clear #bits read/written   
                    // When send receive signal received begin data transmission
                    if(getByte == 1'b1) begin
                        pState2 <= Init2;
                    end
                    else begin
                        pState2 <= Idle2;
                    end   
                end    
                // Init
                Init2 : begin    
                    BUSY <= 1'b1;            // Output a busy signal
                    bitCount <= 4'h0;        // Have not read/written anything yet
                    CE <= 1'b0;                // Disable serial clock    
                    pState2 <= RxTx2;        // Next state receive transmit    
                end   
                // RxTx
                RxTx2 : begin
                    BUSY <= 1'b1;                        // Output busy signal
                    bitCount <= bitCount + 1'b1;    // Begin counting bits received/written    
                    // Have written all bits to slave so prevent another falling edge
                    if(bitCount >= 4'd8) begin
                        CE <= 1'b0;
                    end
                    // Have not written all data, normal operation
                    else begin
                        CE <= 1'b1;
                    end   
                    // Read last bit so data transmission is finished
                    if(bitCount == 4'd8) begin
                        pState2 <= Done2;
                    end
                    // Data transmission is not finished
                    else begin
                        pState2 <= RxTx2;
                    end    
                end   
                // Done
                Done2 : begin    
                    CE <= 1'b0;            // Disable serial clock
                    BUSY <= 1'b1;        // Still busy
                    bitCount <= 4'd0;    // Clear #bits read/written    
                    pState2 <= Idle2;    
                end 
                // Default State
                default : pState2 <= Idle2;
            endcase
        end
    end
    //Interface State Machine End
	// User logic ends
	endmodule
