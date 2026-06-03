module iverilog_dump();
initial begin
    $dumpfile("axis_spi.fst");
    $dumpvars(0, axis_spi);
end
endmodule
