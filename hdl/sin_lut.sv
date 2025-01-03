`default_nettype none

module sin_lut #(
    parameter integer SIN_WIDTH = 17,         // Width of sine values
    parameter integer ANGLE_WIDTH = 8        // Width of input angle (e.g., 0-127 for 128 entries)
)(
    input wire signed [ANGLE_WIDTH-1:0] angle,     // Input angle (e.g., 0-127 for 0° to 180°)
    output logic [SIN_WIDTH-1:0] sin_value, // Output sine value
    output logic sign_bit  // high is negative output
);
    // Sine LUT array
    logic [SIN_WIDTH-1:0] cos_table [0:180]; // enough entries for 

    // Precomputed sine values (16-bit fixed-point, scaled to [0, 65536])
    // 17 BIT　PRECISION
    initial begin
        cos_table[0] = 65536;       // cos(0.0°)
        cos_table[1] = 65526;       // cos(1.0°)
        cos_table[2] = 65496;       // cos(2.0°)
        cos_table[3] = 65446;       // cos(3.0°)
        cos_table[4] = 65376;       // cos(4.0°)
        cos_table[5] = 65286;       // cos(5.0°)
        cos_table[6] = 65176;       // cos(6.0°)
        cos_table[7] = 65047;       // cos(7.0°)
        cos_table[8] = 64898;       // cos(8.0°)
        cos_table[9] = 64729;       // cos(9.0°)
        cos_table[10] = 64540;       // cos(10.0°)
        cos_table[11] = 64331;       // cos(11.0°)
        cos_table[12] = 64103;       // cos(12.0°)
        cos_table[13] = 63856;       // cos(13.0°)
        cos_table[14] = 63589;       // cos(14.0°)
        cos_table[15] = 63302;       // cos(15.0°)
        cos_table[16] = 62997;       // cos(16.0°)
        cos_table[17] = 62672;       // cos(17.0°)
        cos_table[18] = 62328;       // cos(18.0°)
        cos_table[19] = 61965;       // cos(19.0°)
        cos_table[20] = 61583;       // cos(20.0°)
        cos_table[21] = 61183;       // cos(21.0°)
        cos_table[22] = 60763;       // cos(22.0°)
        cos_table[23] = 60326;       // cos(23.0°)
        cos_table[24] = 59870;       // cos(24.0°)
        cos_table[25] = 59395;       // cos(25.0°)
        cos_table[26] = 58903;       // cos(26.0°)
        cos_table[27] = 58393;       // cos(27.0°)
        cos_table[28] = 57864;       // cos(28.0°)
        cos_table[29] = 57319;       // cos(29.0°)
        cos_table[30] = 56755;       // cos(30.0°)
        cos_table[31] = 56175;       // cos(31.0°)
        cos_table[32] = 55577;       // cos(32.0°)
        cos_table[33] = 54963;       // cos(33.0°)
        cos_table[34] = 54331;       // cos(34.0°)
        cos_table[35] = 53683;       // cos(35.0°)
        cos_table[36] = 53019;       // cos(36.0°)
        cos_table[37] = 52339;       // cos(37.0°)
        cos_table[38] = 51643;       // cos(38.0°)
        cos_table[39] = 50931;       // cos(39.0°)
        cos_table[40] = 50203;       // cos(40.0°)
        cos_table[41] = 49460;       // cos(41.0°)
        cos_table[42] = 48702;       // cos(42.0°)
        cos_table[43] = 47929;       // cos(43.0°)
        cos_table[44] = 47142;       // cos(44.0°)
        cos_table[45] = 46340;       // cos(45.0°)
        cos_table[46] = 45525;       // cos(46.0°)
        cos_table[47] = 44695;       // cos(47.0°)
        cos_table[48] = 43852;       // cos(48.0°)
        cos_table[49] = 42995;       // cos(49.0°)
        cos_table[50] = 42125;       // cos(50.0°)
        cos_table[51] = 41243;       // cos(51.0°)
        cos_table[52] = 40347;       // cos(52.0°)
        cos_table[53] = 39440;       // cos(53.0°)
        cos_table[54] = 38521;       // cos(54.0°)
        cos_table[55] = 37589;       // cos(55.0°)
        cos_table[56] = 36647;       // cos(56.0°)
        cos_table[57] = 35693;       // cos(57.0°)
        cos_table[58] = 34728;       // cos(58.0°)
        cos_table[59] = 33753;       // cos(59.0°)
        cos_table[60] = 32768;       // cos(60.0°)
        cos_table[61] = 31772;       // cos(61.0°)
        cos_table[62] = 30767;       // cos(62.0°)
        cos_table[63] = 29752;       // cos(63.0°)
        cos_table[64] = 28729;       // cos(64.0°)
        cos_table[65] = 27696;       // cos(65.0°)
        cos_table[66] = 26655;       // cos(66.0°)
        cos_table[67] = 25606;       // cos(67.0°)
        cos_table[68] = 24550;       // cos(68.0°)
        cos_table[69] = 23486;       // cos(69.0°)
        cos_table[70] = 22414;       // cos(70.0°)
        cos_table[71] = 21336;       // cos(71.0°)
        cos_table[72] = 20251;       // cos(72.0°)
        cos_table[73] = 19160;       // cos(73.0°)
        cos_table[74] = 18064;       // cos(74.0°)
        cos_table[75] = 16961;       // cos(75.0°)
        cos_table[76] = 15854;       // cos(76.0°)
        cos_table[77] = 14742;       // cos(77.0°)
        cos_table[78] = 13625;       // cos(78.0°)
        cos_table[79] = 12504;       // cos(79.0°)
        cos_table[80] = 11380;       // cos(80.0°)
        cos_table[81] = 10252;       // cos(81.0°)
        cos_table[82] = 9120;       // cos(82.0°)
        cos_table[83] = 7986;       // cos(83.0°)
        cos_table[84] = 6850;       // cos(84.0°)
        cos_table[85] = 5711;       // cos(85.0°)
        cos_table[86] = 4571;       // cos(86.0°)
        cos_table[87] = 3429;       // cos(87.0°)
        cos_table[88] = 2287;       // cos(88.0°)
        cos_table[89] = 1143;       // cos(89.0°)
        cos_table[90] = 0;       // cos(90.0°)
        cos_table[91] = 1143;       // cos(91.0°)
        cos_table[92] = 2287;       // cos(92.0°)
        cos_table[93] = 3429;       // cos(93.0°)
        cos_table[94] = 4571;       // cos(94.0°)
        cos_table[95] = 5711;       // cos(95.0°)
        cos_table[96] = 6850;       // cos(96.0°)
        cos_table[97] = 7986;       // cos(97.0°)
        cos_table[98] = 9120;       // cos(98.0°)
        cos_table[99] = 10252;       // cos(99.0°)
        cos_table[100] = 11380;       // cos(100.0°)
        cos_table[101] = 12504;       // cos(101.0°)
        cos_table[102] = 13625;       // cos(102.0°)
        cos_table[103] = 14742;       // cos(103.0°)
        cos_table[104] = 15854;       // cos(104.0°)
        cos_table[105] = 16961;       // cos(105.0°)
        cos_table[106] = 18064;       // cos(106.0°)
        cos_table[107] = 19160;       // cos(107.0°)
        cos_table[108] = 20251;       // cos(108.0°)
        cos_table[109] = 21336;       // cos(109.0°)
        cos_table[110] = 22414;       // cos(110.0°)
        cos_table[111] = 23486;       // cos(111.0°)
        cos_table[112] = 24550;       // cos(112.0°)
        cos_table[113] = 25606;       // cos(113.0°)
        cos_table[114] = 26655;       // cos(114.0°)
        cos_table[115] = 27696;       // cos(115.0°)
        cos_table[116] = 28729;       // cos(116.0°)
        cos_table[117] = 29752;       // cos(117.0°)
        cos_table[118] = 30767;       // cos(118.0°)
        cos_table[119] = 31772;       // cos(119.0°)
        cos_table[120] = 32767;       // cos(120.0°)
        cos_table[121] = 33753;       // cos(121.0°)
        cos_table[122] = 34728;       // cos(122.0°)
        cos_table[123] = 35693;       // cos(123.0°)
        cos_table[124] = 36647;       // cos(124.0°)
        cos_table[125] = 37589;       // cos(125.0°)
        cos_table[126] = 38521;       // cos(126.0°)
        cos_table[127] = 39440;       // cos(127.0°)
        cos_table[128] = 40347;       // cos(128.0°)
        cos_table[129] = 41243;       // cos(129.0°)
        cos_table[130] = 42125;       // cos(130.0°)
        cos_table[131] = 42995;       // cos(131.0°)
        cos_table[132] = 43852;       // cos(132.0°)
        cos_table[133] = 44695;       // cos(133.0°)
        cos_table[134] = 45525;       // cos(134.0°)
        cos_table[135] = 46340;       // cos(135.0°)
        cos_table[136] = 47142;       // cos(136.0°)
        cos_table[137] = 47929;       // cos(137.0°)
        cos_table[138] = 48702;       // cos(138.0°)
        cos_table[139] = 49460;       // cos(139.0°)
        cos_table[140] = 50203;       // cos(140.0°)
        cos_table[141] = 50931;       // cos(141.0°)
        cos_table[142] = 51643;       // cos(142.0°)
        cos_table[143] = 52339;       // cos(143.0°)
        cos_table[144] = 53019;       // cos(144.0°)
        cos_table[145] = 53683;       // cos(145.0°)
        cos_table[146] = 54331;       // cos(146.0°)
        cos_table[147] = 54963;       // cos(147.0°)
        cos_table[148] = 55577;       // cos(148.0°)
        cos_table[149] = 56175;       // cos(149.0°)
        cos_table[150] = 56755;       // cos(150.0°)
        cos_table[151] = 57319;       // cos(151.0°)
        cos_table[152] = 57864;       // cos(152.0°)
        cos_table[153] = 58393;       // cos(153.0°)
        cos_table[154] = 58903;       // cos(154.0°)
        cos_table[155] = 59395;       // cos(155.0°)
        cos_table[156] = 59870;       // cos(156.0°)
        cos_table[157] = 60326;       // cos(157.0°)
        cos_table[158] = 60763;       // cos(158.0°)
        cos_table[159] = 61183;       // cos(159.0°)
        cos_table[160] = 61583;       // cos(160.0°)
        cos_table[161] = 61965;       // cos(161.0°)
        cos_table[162] = 62328;       // cos(162.0°)
        cos_table[163] = 62672;       // cos(163.0°)
        cos_table[164] = 62997;       // cos(164.0°)
        cos_table[165] = 63302;       // cos(165.0°)
        cos_table[166] = 63589;       // cos(166.0°)
        cos_table[167] = 63856;       // cos(167.0°)
        cos_table[168] = 64103;       // cos(168.0°)
        cos_table[169] = 64331;       // cos(169.0°)
        cos_table[170] = 64540;       // cos(170.0°)
        cos_table[171] = 64729;       // cos(171.0°)
        cos_table[172] = 64898;       // cos(172.0°)
        cos_table[173] = 65047;       // cos(173.0°)
        cos_table[174] = 65176;       // cos(174.0°)
        cos_table[175] = 65286;       // cos(175.0°)
        cos_table[176] = 65376;       // cos(176.0°)
        cos_table[177] = 65446;       // cos(177.0°)
        cos_table[178] = 65496;       // cos(178.0°)
        cos_table[179] = 65526;       // cos(179.0°)
        cos_table[180] = 65536;       // cos(180.0°)
    end
    
    logic signed [9:0] signed_result; // size is determined as sufficient
    logic [ANGLE_WIDTH-1:0] cos_angle;

    logic signed [ANGLE_WIDTH-1:0] base;

    assign signed_result = 9'sd90 - angle;

    assign cos_angle = $unsigned(signed_result);
    // Map input angle to LUT value

    assign sin_value = cos_table[cos_angle];
    assign sign_bit = cos_angle > 90;

endmodule

`default_nettype wire