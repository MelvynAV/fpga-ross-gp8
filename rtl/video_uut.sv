/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack-a-Thon 2026
****************************************************************************/

/*  INSTANTIATION TEMPLATE  -------------------------------------------------

video_uut video_uut (       
    .clk_i          ( ),//               
    .cen_i          ( ),// video clock enable
    .rst_i          ( ),//
    .vid_sel_i      ( ),//
    .vid_rgb_i      ( ),//[23:0] = R[23:16], G[15:8], B[7:0]
    .vh_blank_i     ( ),//[ 1:0] = {Vblank, Hblank}
    .dvh_sync_i     ( ),//[ 2:0] = {D_sync, Vsync , Hsync }
    // Output signals
    .dvh_sync_o     ( ),//[ 2:0] = {D_sync, Vsync , Hsync }  delayed
    .vid_rgb_o      ( ) //[23:0] = R[23:16], G[15:8], B[7:0] delayed
);

-------------------------------------------------------------------------- */

module video_uut (
    input  wire         clk_i,
    input  wire         cen_i,
    input  wire         rst_i,
    input  wire         vid_sel_i,
    input  wire [23:0]  vid_rgb_i,
    input  wire [1:0]   vh_blank_i,
    input  wire [2:0]   dvh_sync_i,
    output wire [2:0]   dvh_sync_o,
    output wire [23:0]  vid_rgb_o
);

    // ============================================================
    // Active area (assumed 1080p)
    // ============================================================
    localparam integer H_ACTIVE = 1920;
    localparam integer V_ACTIVE = 1080;

    // ---------- Colors ----------
    localparam [23:0] SKY_BG      = 24'h070A12;
    localparam [23:0] CROWD_DARK  = 24'h0E0F16;
    localparam [23:0] CROWD_LIGHT = 24'h1A1C28;

    localparam [23:0] GRASS_A     = 24'h0A5C1F;
    localparam [23:0] GRASS_B     = 24'h0D6A26;
    localparam [23:0] LINE_WHITE  = 24'hF5F7FF;

    localparam [23:0] TEAM_A      = 24'h1E5BFF;
    localparam [23:0] TEAM_B      = 24'hFF2A2A;
    localparam [23:0] OUTLINE     = 24'h05060A;
    localparam [23:0] SKIN        = 24'hC68642;
    localparam [23:0] SHADOW      = 24'h151515;

    localparam [23:0] BALL_WHITE  = 24'hF7F7F7;
    localparam [23:0] BALL_DARK   = 24'hD6D6D6;

    localparam [23:0] SCORE_BG    = 24'h0E1016;
    localparam [23:0] SCORE_FG    = 24'hECEFF4;
    localparam [23:0] SCORE_ACC   = 24'hFFD200;
    localparam [23:0] LIVE_RED    = 24'hD3122A;

    // ---------- Field geometry ----------
    localparam integer MARGIN_X = 60;
    localparam integer MARGIN_Y = 70;

    localparam integer PITCH_L = MARGIN_X;
    localparam integer PITCH_R = H_ACTIVE - MARGIN_X - 1;
    localparam integer PITCH_T = MARGIN_Y;
    localparam integer PITCH_B = V_ACTIVE - MARGIN_Y - 1;

    localparam integer PITCH_W = (PITCH_R - PITCH_L + 1);
    localparam integer PITCH_H = (PITCH_B - PITCH_T + 1);

    // Scoreboard placed under pitch (in bottom margin)
    localparam integer SB_TOP = PITCH_B + 12;
    localparam integer SB_H   = 64;
    localparam integer SB_BOT = SB_TOP + SB_H;
    localparam integer SB_L   = 40;
    localparam integer SB_R   = 620;

    // Player limits derived from pitch limits (IMPORTANT)
    localparam integer PL_MARGIN = 20;
    localparam integer PL_L = PITCH_L + PL_MARGIN;
    localparam integer PL_R = PITCH_R - PL_MARGIN;
    localparam integer PL_T = PITCH_T + PL_MARGIN;
    localparam integer PL_B = PITCH_B - PL_MARGIN;

    // Goals
    localparam integer GOAL_MOUTH_H = 240;
    localparam integer GOAL_T = (V_ACTIVE/2) - (GOAL_MOUTH_H/2);
    localparam integer GOAL_B = (V_ACTIVE/2) + (GOAL_MOUTH_H/2);
    localparam integer GOAL_DEPTH = 22;

    // ============================================================
    // TOP RIGHT BANNER geometry (ROSS VIDEO)
    // ============================================================
    localparam integer BANNER_W  = 430;
    localparam integer BANNER_H  = 48;
    localparam integer BANNER_T  = 12;
    localparam integer BANNER_RM = 20;
    localparam integer BANNER_L0 = H_ACTIVE - BANNER_W - BANNER_RM;

    // ============================================================
    // TIMING (DE-based)
    // ============================================================
    wire de_i    = dvh_sync_i[2]; // D_sync / DE
    wire vsync_i = dvh_sync_i[1];
    wire hsync_i = dvh_sync_i[0];

    reg  de_d = 1'b0;
    wire de_rise =  de_i & ~de_d;
    wire de_fall = ~de_i &  de_d;

    // kept for compatibility; not used for counters/tick
    wire h_active = ~vh_blank_i[0];
    wire v_active = ~vh_blank_i[1];

    reg [11:0] h_cnt = 12'd0;
    reg [10:0] v_cnt = 11'd0;

    reg in_active_line      = 1'b0;
    reg saw_any_active      = 1'b0;
    reg frame_wrap_pending  = 1'b0;
    reg frame_tick          = 1'b0;

    always @(posedge clk_i) begin
        if (rst_i) begin
            de_d <= 1'b0;
        end else if (cen_i) begin
            de_d <= de_i;
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            h_cnt <= 0;
            v_cnt <= 0;
            in_active_line <= 1'b0;
            saw_any_active <= 1'b0;
            frame_wrap_pending <= 1'b0;
            frame_tick <= 1'b0;
        end else if (cen_i) begin
            frame_tick <= 1'b0;

            if (de_fall) begin
                in_active_line <= 1'b0;
                if (saw_any_active && (v_cnt == V_ACTIVE-1)) begin
                    frame_wrap_pending <= 1'b1;
                end
            end

            if (de_rise) begin
                in_active_line <= 1'b1;
                h_cnt <= 0;

                if (!saw_any_active) begin
                    saw_any_active <= 1'b1;
                    v_cnt <= 0;
                    frame_tick <= 1'b1;
                end else if (frame_wrap_pending) begin
                    frame_wrap_pending <= 1'b0;
                    v_cnt <= 0;
                    frame_tick <= 1'b1;
                end else begin
                    if (v_cnt != V_ACTIVE-1) v_cnt <= v_cnt + 1;
                end
            end else if (in_active_line) begin
                if (h_cnt != H_ACTIVE-1) h_cnt <= h_cnt + 1;
            end
        end
    end

    // ============================================================
    // Helpers
    // ============================================================
    function [7:0] clamp8(input integer x);
        begin
            if (x < 0) clamp8 = 8'd0;
            else if (x > 255) clamp8 = 8'd255;
            else clamp8 = x[7:0];
        end
    endfunction

    // Saturating +/- on RGB to avoid wrap-around artifacts (green glitch lines)
    function automatic [23:0] rgb_add_uni(input [23:0] c, input integer d);
        integer r,g,b;
        begin
            r = integer'(c[23:16]) + d;
            g = integer'(c[15:8])  + d;
            b = integer'(c[7:0])   + d;
            rgb_add_uni = {clamp8(r), clamp8(g), clamp8(b)};
        end
    endfunction

    // ============================================================
    // RNG (global)
    // ============================================================
    reg [15:0] lfsr = 16'hACE1;
    wire lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    // ============================================================
    // Game state
    // ============================================================
    reg [31:0] frame_cnt = 0;

    // 2 minute game
    reg [7:0] sec = 8'd120;
    reg [7:0] frame_div = 0;

    reg [3:0] score_a = 0;
    reg [3:0] score_b = 0;

    // Ball
    reg signed [11:0] ball_x;
    reg signed [10:0] ball_y;
    reg signed [11:0] ball_vx;
    reg signed [11:0] ball_vy;
    localparam integer BALL_R = 10;

    // Players
    localparam integer NPLAY = 12;

    reg signed [11:0] pl_x [0:NPLAY-1];
    reg signed [10:0] pl_y [0:NPLAY-1];

    reg signed [11:0] tgt_x [0:NPLAY-1];
    reg signed [10:0] tgt_y [0:NPLAY-1];

    // Fixed-point position (12.4) and velocity (12.4)
    reg signed [15:0] pos_x [0:NPLAY-1];
    reg signed [15:0] pos_y [0:NPLAY-1];
    reg signed [15:0] vel_x [0:NPLAY-1];
    reg signed [15:0] vel_y [0:NPLAY-1];

    reg [15:0] prng [0:NPLAY-1];
    reg [7:0]  pl_anim [0:NPLAY-1];

    // Two closest players overall
    integer best0_i, best1_i;
    integer best0_d2, best1_d2;

    // Kick cooldown
    reg [5:0] kick_cd = 0;

    reg [1:0]  goal_side;
    reg [9:0]  goal_anim;
    reg [7:0]  flash;
    reg [7:0]  match_id;
    reg [7:0]  kickoff_pause;

    reg init_done = 1'b0;

    // loop vars (Vivado-friendly: avoid "for (int ...)" in some modes)
    integer k_loop;
    integer p_loop;

    // ============================================================
    // Formation functions (combinational)
    // ============================================================
    function automatic signed [11:0] home_x_fn(input integer idx);
        begin
            case (idx)
                0:  home_x_fn = PITCH_L+190;
                1:  home_x_fn = PITCH_L+430;
                2:  home_x_fn = PITCH_L+430;
                3:  home_x_fn = PITCH_L+750;
                4:  home_x_fn = PITCH_L+750;
                5:  home_x_fn = PITCH_L+980;
                6:  home_x_fn = PITCH_R-190;
                7:  home_x_fn = PITCH_R-430;
                8:  home_x_fn = PITCH_R-430;
                9:  home_x_fn = PITCH_R-750;
                10: home_x_fn = PITCH_R-750;
                11: home_x_fn = PITCH_R-980;
                default: home_x_fn = H_ACTIVE/2;
            endcase
        end
    endfunction

    function automatic signed [10:0] home_y_fn(input integer idx);
        begin
            case (idx)
                0:  home_y_fn = V_ACTIVE/2;
                1:  home_y_fn = PITCH_T+230;
                2:  home_y_fn = PITCH_B-230;
                3:  home_y_fn = PITCH_T+300;
                4:  home_y_fn = PITCH_B-300;
                5:  home_y_fn = V_ACTIVE/2;
                6:  home_y_fn = V_ACTIVE/2;
                7:  home_y_fn = PITCH_T+230;
                8:  home_y_fn = PITCH_B-230;
                9:  home_y_fn = PITCH_T+300;
                10: home_y_fn = PITCH_B-300;
                11: home_y_fn = V_ACTIVE/2;
                default: home_y_fn = V_ACTIVE/2;
            endcase
        end
    endfunction

    // ============================================================
    // kickoff reset task (random ball position inside play area)
    // ============================================================
    task do_kickoff_reset;
        integer k;
        integer rx, ry;
        integer x_max, y_max;
        begin
            // safe spawn inside playable area (ball fits fully inside)
            x_max = (PL_R - BALL_R);
            y_max = (PL_B - BALL_R);

            rx = (PL_L + BALL_R) + {5'b0, lfsr[10:0]};
            ry = (PL_T + BALL_R) + {6'b0, lfsr[9:0]};

            if (rx > x_max) rx = x_max;
            if (ry > y_max) ry = y_max;

            ball_x  <= rx[11:0];
            ball_y  <= ry[10:0];
            ball_vx <= 0;
            ball_vy <= 0;

            kickoff_pause <= 8'd30;
            kick_cd <= 6'd0;

            for (k = 0; k < NPLAY; k = k + 1) begin
                pl_x[k]  <= home_x_fn(k);
                pl_y[k]  <= home_y_fn(k);
                tgt_x[k] <= home_x_fn(k);
                tgt_y[k] <= home_y_fn(k);

                pos_x[k] <= {home_x_fn(k),4'b0000};
                pos_y[k] <= {home_y_fn(k),4'b0000};
                vel_x[k] <= 16'sd0;
                vel_y[k] <= 16'sd0;

                pl_anim[k] <= 0;
            end
        end
    endtask

    // ============================================================
    // (NEW) Players-only reset (used on GOAL so ball can be forced center)
    // ============================================================
    task do_players_home_reset;
        integer k;
        begin
            for (k = 0; k < NPLAY; k = k + 1) begin
                pl_x[k]  <= home_x_fn(k);
                pl_y[k]  <= home_y_fn(k);
                tgt_x[k] <= home_x_fn(k);
                tgt_y[k] <= home_y_fn(k);

                pos_x[k] <= {home_x_fn(k),4'b0000};
                pos_y[k] <= {home_y_fn(k),4'b0000};
                vel_x[k] <= 16'sd0;
                vel_y[k] <= 16'sd0;

                pl_anim[k] <= 0;
            end
        end
    endtask

    // ============================================================
    // Gameplay / physics update (runs on frame_tick)
    // ============================================================
    integer dx, dy, d2;
    integer tx, ty;

    reg signed [15:0] px_fp, py_fp;
    reg signed [15:0] vx_fp, vy_fp;

    // Tuning
    localparam integer KICK_RADIUS2 = 1600;      // (40px)^2
    localparam integer PLAYER_MAXV  = (4 <<< 4); // ~4px/frame (players slower)
    localparam integer PLAYER_ACC   = (1 <<< 4); // ~1px/frame^2
    localparam integer BALL_MAXV    = 20;        // clamp
    localparam integer BALL_FRICTION_SHIFT = 5;  // decay

    function automatic signed [15:0] clamp_vel(input signed [15:0] v);
        begin
            if (v >  PLAYER_MAXV) clamp_vel =  PLAYER_MAXV;
            else if (v < -PLAYER_MAXV) clamp_vel = -PLAYER_MAXV;
            else clamp_vel = v;
        end
    endfunction

    // temporaries for ball integration/collisions (prevents 1-frame lag bugs)
    integer nbx, nby;
    integer nvx, nvy;

    // moved out of inner block for Vivado/Vlog compatibility (declaration-only)
    integer goal_hit;

    always @(posedge clk_i) begin
        if (rst_i) begin
            init_done <= 1'b0;

            frame_cnt <= 0;
            lfsr <= 16'hACE1;

            sec <= 8'd120;
            frame_div <= 0;

            score_a <= 0;
            score_b <= 0;

            match_id <= 8'h01;

            goal_side <= 0;
            goal_anim <= 0;
            flash <= 0;
            kickoff_pause <= 0;
            kick_cd <= 0;

            ball_x  <= H_ACTIVE/2;
            ball_y  <= V_ACTIVE/2;
            ball_vx <= 0;
            ball_vy <= 0;

            for (k_loop = 0; k_loop < NPLAY; k_loop = k_loop + 1) begin
                pl_x[k_loop]    <= home_x_fn(k_loop);
                pl_y[k_loop]    <= home_y_fn(k_loop);
                tgt_x[k_loop]   <= home_x_fn(k_loop);
                tgt_y[k_loop]   <= home_y_fn(k_loop);

                pos_x[k_loop]   <= {home_x_fn(k_loop),4'b0000};
                pos_y[k_loop]   <= {home_y_fn(k_loop),4'b0000};
                vel_x[k_loop]   <= 16'sd0;
                vel_y[k_loop]   <= 16'sd0;

                pl_anim[k_loop] <= 0;
                prng[k_loop]    <= 16'hBEEF ^ (k_loop*16'h1234) ^ 16'h0001;
            end

        end else if (cen_i) begin
            if (frame_tick) begin

                // Boot safety if rst not asserted
                if (!init_done) begin
                    init_done <= 1'b1;
                    score_a <= 0;
                    score_b <= 0;
                    sec <= 8'd120;
                    frame_div <= 0;
                    match_id <= 8'h01;
                    goal_side <= 0;
                    goal_anim <= 0;
                    flash <= 0;
                    do_kickoff_reset();
                    for (k_loop = 0; k_loop < NPLAY; k_loop = k_loop + 1) begin
                        prng[k_loop] <= 16'hBEEF ^ (k_loop*16'h1234) ^ 16'h0001;
                        pl_anim[k_loop] <= 0;
                    end
                end

                frame_cnt <= frame_cnt + 1;
                lfsr <= {lfsr[14:0], lfsr_fb};

                // Decays
                if (flash != 0) flash <= (flash > 8'd10) ? (flash - 8'd10) : 0;
                if (goal_anim != 0) goal_anim <= goal_anim - 1;

                // ---------------- 2-minute timer ----------------
                frame_div <= frame_div + 1;
                if (frame_div == 8'd59) begin
                    frame_div <= 0;
                    if (sec != 0) begin
                        sec <= sec - 1;
                    end else begin
                        // reset match
                        sec <= 8'd120;
                        score_a <= 0;
                        score_b <= 0;

                        match_id <= match_id + 1;
                        lfsr <= lfsr ^ {8'h00, match_id};

                        goal_side <= 0;
                        goal_anim <= 0;
                        flash <= 0;

                        do_kickoff_reset();
                    end
                end

                if (kickoff_pause != 0) kickoff_pause <= kickoff_pause - 1;
                if (kick_cd != 0)       kick_cd <= kick_cd - 1;

                // Give ball a tiny nudge right after kickoff pause ends (keeps flow)
                if (kickoff_pause == 8'd1) begin
                    ball_vx <= (lfsr[0] ? 12'sd6 : -12'sd6);
                    ball_vy <= $signed({{8{lfsr[4]}}, lfsr[7:4]}); // small signed
                end

                // ---------------- update prng + roaming targets ----------------
                for (k_loop = 0; k_loop < NPLAY; k_loop = k_loop + 1) begin
                    prng[k_loop] <= {prng[k_loop][14:0], prng[k_loop][15] ^ prng[k_loop][13] ^ prng[k_loop][12] ^ prng[k_loop][10]} ^ (16'h9E37 + k_loop);
                    pl_anim[k_loop] <= pl_anim[k_loop] + 1;

                    if (((frame_cnt[3:0] ^ k_loop[3:0]) == 4'h0) && (kickoff_pause == 0) && (goal_anim == 0)) begin
                        tx = home_x_fn(k_loop) + (((prng[k_loop][7:0])  - 8'd128) >>> 1);
                        ty = home_y_fn(k_loop) + (((prng[k_loop][15:8]) - 8'd128) >>> 2);

                        // bias slightly toward ball side
                        if (k_loop < 6) begin
                            if (ball_x > H_ACTIVE/2) tx = tx + 40;
                        end else begin
                            if (ball_x < H_ACTIVE/2) tx = tx - 40;
                        end

                        // clamp targets
                        if (tx < PL_L) tx = PL_L;
                        if (tx > PL_R) tx = PL_R;
                        if (ty < PL_T) ty = PL_T;
                        if (ty > PL_B) ty = PL_B;

                        tgt_x[k_loop] <= tx[11:0];
                        tgt_y[k_loop] <= ty[10:0];
                    end
                end

                // ---------------- two closest players to the ball ----------------
                best0_i  = 0; best1_i  = 1;
                best0_d2 = 32'h7fffffff;
                best1_d2 = 32'h7fffffff;

                for (k_loop = 0; k_loop < NPLAY; k_loop = k_loop + 1) begin
                    dx = (pl_x[k_loop] - ball_x);
                    dy = (pl_y[k_loop] - ball_y);
                    d2 = dx*dx + dy*dy;

                    if (d2 < best0_d2) begin
                        best1_d2 = best0_d2; best1_i = best0_i;
                        best0_d2 = d2;       best0_i = k_loop;
                    end else if (d2 < best1_d2) begin
                        best1_d2 = d2;       best1_i = k_loop;
                    end
                end

                // ---------------- PLAYER PHYSICS ----------------
                for (k_loop = 0; k_loop < NPLAY; k_loop = k_loop + 1) begin
                    px_fp = pos_x[k_loop];
                    py_fp = pos_y[k_loop];
                    vx_fp = vel_x[k_loop];
                    vy_fp = vel_y[k_loop];

                    if ((kickoff_pause == 0) && (goal_anim == 0)) begin
                        // two closest chase; others roam
                        if (k_loop == best0_i || k_loop == best1_i) begin
                            tx = ball_x;
                            ty = ball_y;
                        end else begin
                            tx = tgt_x[k_loop];
                            ty = tgt_y[k_loop];
                        end

                        dx = tx - (px_fp >>> 4);
                        dy = ty - (py_fp >>> 4);

                        if (dx > 2)       vx_fp = vx_fp + PLAYER_ACC;
                        else if (dx < -2) vx_fp = vx_fp - PLAYER_ACC;

                        if (dy > 2)       vy_fp = vy_fp + PLAYER_ACC;
                        else if (dy < -2) vy_fp = vy_fp - PLAYER_ACC;

                        // damping
                        vx_fp = vx_fp - (vx_fp >>> 3);
                        vy_fp = vy_fp - (vy_fp >>> 3);

                        // clamp (players slower)
                        vx_fp = clamp_vel(vx_fp);
                        vy_fp = clamp_vel(vy_fp);

                        // integrate
                        px_fp = px_fp + vx_fp;
                        py_fp = py_fp + vy_fp;
                    end

                    // clamp position
                    if ((px_fp >>> 4) < PL_L) begin px_fp = (PL_L <<< 4); vx_fp = 0; end
                    if ((px_fp >>> 4) > PL_R) begin px_fp = (PL_R <<< 4); vx_fp = 0; end
                    if ((py_fp >>> 4) < PL_T) begin py_fp = (PL_T <<< 4); vy_fp = 0; end
                    if ((py_fp >>> 4) > PL_B) begin py_fp = (PL_B <<< 4); vy_fp = 0; end

                    pos_x[k_loop] <= px_fp;
                    pos_y[k_loop] <= py_fp;
                    vel_x[k_loop] <= vx_fp;
                    vel_y[k_loop] <= vy_fp;

                    pl_x[k_loop] <= (px_fp >>> 4);
                    pl_y[k_loop] <= (py_fp >>> 4);
                end

                // ---------------- BALL PHYSICS + SOCCER ----------------
                if ((kickoff_pause == 0) && (goal_anim == 0)) begin
                    // start from current
                    nbx = ball_x;
                    nby = ball_y;
                    nvx = ball_vx;
                    nvy = ball_vy;

                    // move
                    nbx = nbx + nvx;
                    nby = nby + nvy;

                    // friction
                    nvx = nvx - (nvx >>> BALL_FRICTION_SHIFT);
                    nvy = nvy - (nvy >>> BALL_FRICTION_SHIFT);

                    // clamp velocity
                    if (nvx >  BALL_MAXV) nvx =  BALL_MAXV;
                    if (nvx < -BALL_MAXV) nvx = -BALL_MAXV;
                    if (nvy >  BALL_MAXV) nvy =  BALL_MAXV;
                    if (nvy < -BALL_MAXV) nvy = -BALL_MAXV;

                    // bounce top/bottom
                    if (nby < (PITCH_T + BALL_R)) begin
                        nby = PITCH_T + BALL_R;
                        nvy = -nvy;
                    end
                    if (nby > (PITCH_B - BALL_R)) begin
                        nby = PITCH_B - BALL_R;
                        nvy = -nvy;
                    end

                    // ----------------------------------------------------------------
                    // On GOAL, force the ball to center immediately
                    // ----------------------------------------------------------------
                    goal_hit = 0;

                    // left side (goal or wall)
                    if (!goal_hit && (nbx <= (PITCH_L + BALL_R))) begin
                        if (nby >= GOAL_T && nby <= GOAL_B) begin
                            goal_hit = 1;

                            if (score_b != 9) score_b <= score_b + 1;
                            goal_side <= 2;
                            goal_anim <= 10'd140;
                            flash <= 8'd220;

                            // players reset, and ball goes to middle
                            do_players_home_reset();
                            kickoff_pause <= 8'd30;
                            kick_cd <= 6'd0;

                            nbx = H_ACTIVE/2;
                            nby = V_ACTIVE/2;
                            nvx = 0;
                            nvy = 0;
                        end else begin
                            nbx = PITCH_L + BALL_R;
                            nvx = -nvx;
                        end
                    end

                    // right side (goal or wall)
                    if (!goal_hit && (nbx >= (PITCH_R - BALL_R))) begin
                        if (nby >= GOAL_T && nby <= GOAL_B) begin
                            goal_hit = 1;

                            if (score_a != 9) score_a <= score_a + 1;
                            goal_side <= 1;
                            goal_anim <= 10'd140;
                            flash <= 8'd220;

                            // players reset, and ball goes to middle
                            do_players_home_reset();
                            kickoff_pause <= 8'd30;
                            kick_cd <= 6'd0;

                            nbx = H_ACTIVE/2;
                            nby = V_ACTIVE/2;
                            nvx = 0;
                            nvy = 0;
                        end else begin
                            nbx = PITCH_R - BALL_R;
                            nvx = -nvx;
                        end
                    end

                    // kick when closest reaches the ball (team-based) + cooldown
                    if (!goal_hit && (best0_d2 < KICK_RADIUS2) && (kick_cd == 0)) begin
                        if (best0_i < 6) begin
                            // Team A attacks RIGHT
                            nvx = 18 + $signed({8'd0, lfsr[3:0]});
                        end else begin
                            // Team B attacks LEFT
                            nvx = -(18 + $signed({8'd0, lfsr[3:0]}));
                        end
                        nvy = ($signed({{8{lfsr[7]}}, lfsr[7:4]}) - 8);
                        kick_cd <= 6'd20;
                    end

                    // commit ball state
                    ball_x  <= nbx[11:0];
                    ball_y  <= nby[10:0];
                    ball_vx <= nvx[11:0];
                    ball_vy <= nvy[11:0];
                end
            end
        end
    end

    // ============================================================
    // 3x5 digit renderer
    // ============================================================
    function [14:0] digit3x5(input [3:0] d);
        begin
            case (d)
                0: digit3x5 = 15'b111_101_101_101_111;
                1: digit3x5 = 15'b010_110_010_010_111;
                2: digit3x5 = 15'b111_001_111_100_111;
                3: digit3x5 = 15'b111_001_111_001_111;
                4: digit3x5 = 15'b101_101_111_001_001;
                5: digit3x5 = 15'b111_100_111_001_111;
                6: digit3x5 = 15'b111_100_111_101_111;
                7: digit3x5 = 15'b111_001_001_001_001;
                8: digit3x5 = 15'b111_101_111_101_111;
                9: digit3x5 = 15'b111_101_111_001_111;
                default: digit3x5 = 15'b000_000_000_000_000;
            endcase
        end
    endfunction

    // explicit 1-bit return type (Vivado-friendly)
    function automatic bit digit_pixel(
        input [11:0] x,
        input [10:0] y,
        input [11:0] x0,
        input [10:0] y0,
        input [3:0]  d
    );
        reg [2:0] lx;
        reg [2:0] ly;
        reg [14:0] bm;
        integer idx;
        begin
            digit_pixel = 1'b0;
            if (x >= x0 && x < x0 + 3*6 && y >= y0 && y < y0 + 5*6) begin
                lx = (x - x0) / 6;
                ly = (y - y0) / 6;
                bm = digit3x5(d);
                idx = (4-ly)*3 + (2-lx);
                digit_pixel = bm[idx];
            end
        end
    endfunction

    // ============================================================
    // 5x7 font (caps only)
    // ============================================================
    function [34:0] font5x7(input [7:0] ch);
        begin
            case (ch)
                "E": font5x7 = 35'b11111_10000_11110_10000_10000_10000_11111;
                "S": font5x7 = 35'b01111_10000_10000_01110_00001_00001_11110;
                "P": font5x7 = 35'b11110_10001_10001_11110_10000_10000_10000;
                "N": font5x7 = 35'b10001_11001_10101_10011_10001_10001_10001;
                "L": font5x7 = 35'b10000_10000_10000_10000_10000_10000_11111;
                "I": font5x7 = 35'b11111_00100_00100_00100_00100_00100_11111;
                "V": font5x7 = 35'b10001_10001_10001_10001_10001_01010_00100;
                "G": font5x7 = 35'b01110_10001_10000_10111_10001_10001_01110;
                "O": font5x7 = 35'b01110_10001_10001_10001_10001_10001_01110;
                "A": font5x7 = 35'b01110_10001_10001_11111_10001_10001_10001;
                "R": font5x7 = 35'b11110_10001_10001_11110_10100_10010_10001;
                "D": font5x7 = 35'b11110_10001_10001_10001_10001_10001_11110;
                "!": font5x7 = 35'b00100_00100_00100_00100_00100_00000_00100;
                " ": font5x7 = 35'b00000_00000_00000_00000_00000_00000_00000;
                default: font5x7 = 35'b00000_00000_00000_00000_00000_00000_00000;
            endcase
        end
    endfunction

    // explicit 1-bit return type (Vivado-friendly)
    function automatic bit text_pixel5x7(
        input [11:0] x,
        input [10:0] y,
        input [11:0] x0,
        input [10:0] y0,
        input [7:0]  ch
    );
        integer lx, ly, bitidx;
        reg [34:0] bm;
        begin
            text_pixel5x7 = 1'b0;
            if (x >= x0 && x < x0 + 5*2 && y >= y0 && y < y0 + 7*2) begin
                lx = (x - x0) / 2;
                ly = (y - y0) / 2;
                bm = font5x7(ch);
                bitidx = (6-ly)*5 + (4-lx);
                text_pixel5x7 = bm[bitidx];
            end
        end
    endfunction

    // explicit 1-bit return type (Vivado-friendly)
    function automatic bit stringpix(
        input [11:0] x,  input [10:0] y,
        input [11:0] x0, input [10:0] y0,
        input [7:0] c0,  input [7:0] c1,  input [7:0] c2,  input [7:0] c3,
        input [7:0] c4,  input [7:0] c5,  input [7:0] c6,  input [7:0] c7,
        input [7:0] c8,  input [7:0] c9,  input [7:0] c10, input [7:0] c11
    );
        reg hit;
        begin
            hit = 1'b0;
            if (text_pixel5x7(x,y,x0 +  0,y0,c0 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 12,y0,c1 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 24,y0,c2 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 36,y0,c3 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 48,y0,c4 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 60,y0,c5 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 72,y0,c6 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 84,y0,c7 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 + 96,y0,c8 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 +108,y0,c9 )) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 +120,y0,c10)) hit = 1'b1;
            if (text_pixel5x7(x,y,x0 +132,y0,c11)) hit = 1'b1;
            stringpix = hit;
        end
    endfunction

    // ============================================================
    // Pixel pipeline
    // ============================================================
    reg [23:0] vid_rgb_d1;
    reg [2:0]  dvh_sync_d1;

    reg in_pitch;
    reg [23:0] grass;
    integer bx, by;
    integer px, py;
    integer pw, ph, head_r;

    integer ddx, ddy, dist2;
    reg [23:0] col;

    integer mm, ss; // for scoreboard MM:SS

    // Banner vars
    integer banner_l;
    integer wobble;

    function [23:0] apply_flash(input [23:0] c, input [7:0] f);
        integer r,g,b;
        begin
            r = c[23:16] + (f >>> 1);
            g = c[15:8]  + (f >>> 1);
            b = c[7:0]   + (f >>> 1);
            apply_flash = {clamp8(r), clamp8(g), clamp8(b)};
        end
    endfunction

    always @(posedge clk_i) begin
        if (rst_i) begin
            vid_rgb_d1   <= 24'h000000;
            dvh_sync_d1  <= 3'b000;
            in_pitch     <= 1'b0;
            grass        <= 24'h000000;
        end else if (cen_i) begin
            // defaults each pixel (avoid stale state usage)
            in_pitch = 1'b0;
            grass   = GRASS_A;
            col     = SKY_BG;

            vid_rgb_d1 <= SKY_BG;

            if (vid_sel_i && de_i) begin
                in_pitch = (h_cnt >= PITCH_L && h_cnt <= PITCH_R && v_cnt >= PITCH_T && v_cnt <= PITCH_B);

                // crowd
                if (v_cnt < PITCH_T) begin
                    col = (((h_cnt >> 5) & 1) == 0) ? CROWD_DARK : CROWD_LIGHT;
                    vid_rgb_d1 <= apply_flash(col, flash);
                end else if (v_cnt > PITCH_B) begin
                    col = (((h_cnt >> 5) & 1) == 0) ? CROWD_LIGHT : CROWD_DARK;
                    vid_rgb_d1 <= apply_flash(col, flash);
                end

                // pitch base
                if (in_pitch) begin
                    grass = (((h_cnt >> 6) & 1) == 0) ? GRASS_A : GRASS_B;

                    if (((h_cnt >> 8) & 1) == 1) grass = rgb_add_uni(grass, 1);

                    if (v_cnt[6:0] < 7'd50) col = rgb_add_uni(grass, 3);
                    else if (v_cnt[6:0] > 7'd120) col = rgb_add_uni(grass, -1);
                    else col = grass;

                    vid_rgb_d1 <= apply_flash(col, flash);

                    // outer lines thick
                    if (h_cnt == PITCH_L+2 || h_cnt == PITCH_L+3 || h_cnt == PITCH_L+4 ||
                        h_cnt == PITCH_R-2 || h_cnt == PITCH_R-3 || h_cnt == PITCH_R-4 ||
                        v_cnt == PITCH_T+2 || v_cnt == PITCH_T+3 || v_cnt == PITCH_T+4 ||
                        v_cnt == PITCH_B-2 || v_cnt == PITCH_B-3 || v_cnt == PITCH_B-4)
                        vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);

                    // MIDFIELD LINE: VERTICAL
                    if ((h_cnt == (PITCH_L + (PITCH_W/2)) || h_cnt == (PITCH_L + (PITCH_W/2) + 1)) &&
                        v_cnt >= PITCH_T && v_cnt <= PITCH_B)
                        vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);

                    // center circle
                    ddx = integer'(h_cnt) - (H_ACTIVE/2);
                    ddy = integer'(v_cnt) - (V_ACTIVE/2);
                    dist2 = ddx*ddx + ddy*ddy;
                    if ((dist2 >= (155*155)) && (dist2 <= (157*157)))
                        vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);

                    // goal frames + net
                    if (h_cnt >= (PITCH_L+2) && h_cnt <= (PITCH_L+2+GOAL_DEPTH) &&
                        v_cnt >= GOAL_T && v_cnt <= GOAL_B) begin
                        if (h_cnt == PITCH_L+2 || h_cnt == PITCH_L+3) vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);
                        if (v_cnt == GOAL_T || v_cnt == GOAL_T+1 || v_cnt == GOAL_B || v_cnt == GOAL_B-1)
                            vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);
                        if (((h_cnt + v_cnt) & 7) == 0) vid_rgb_d1 <= apply_flash(24'hCFCFCF, flash);
                    end

                    if (h_cnt <= (PITCH_R-2) && h_cnt >= (PITCH_R-2-GOAL_DEPTH) &&
                        v_cnt >= GOAL_T && v_cnt <= GOAL_B) begin
                        if (h_cnt == PITCH_R-2 || h_cnt == PITCH_R-3) vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);
                        if (v_cnt == GOAL_T || v_cnt == GOAL_T+1 || v_cnt == GOAL_B || v_cnt == GOAL_B-1)
                            vid_rgb_d1 <= apply_flash(LINE_WHITE, flash);
                        if (((h_cnt + v_cnt) & 7) == 0) vid_rgb_d1 <= apply_flash(24'hCFCFCF, flash);
                    end
                end

                // players
                for (p_loop = 0; p_loop < NPLAY; p_loop = p_loop + 1) begin
                    px = pl_x[p_loop];
                    py = pl_y[p_loop];
                    pw = 18 + ((py - PITCH_T) >> 5);
                    ph = 46 + ((py - PITCH_T) >> 4);
                    head_r = (pw >> 2);

                    // shadow
                    ddx = integer'(h_cnt) - (px + 6);
                    ddy = integer'(v_cnt) - (py + 6);
                    if (in_pitch && (ddx*ddx + ddy*ddy) <= 170)
                        vid_rgb_d1 <= apply_flash(SHADOW, flash);

                    // body
                    if (integer'(h_cnt) >= (px - pw/2) && integer'(h_cnt) < (px + pw/2) &&
                        integer'(v_cnt) >= (py - ph) && integer'(v_cnt) < py) begin
                        col = (p_loop < 6) ? TEAM_A : TEAM_B;

                        if (((h_cnt + (pl_anim[p_loop]>>2)) & 8) == 0) col = rgb_add_uni(col, 3);
                        if (v_cnt > (py - (ph>>2)))                   col = rgb_add_uni(col, -2);

                        vid_rgb_d1 <= apply_flash(col, flash);

                        if (h_cnt == (px - pw/2) || h_cnt == (px + pw/2 - 1) ||
                            v_cnt == (py - ph) || v_cnt == (py - 1))
                            vid_rgb_d1 <= apply_flash(OUTLINE, flash);
                    end

                    // head
                    ddx = integer'(h_cnt) - px;
                    ddy = integer'(v_cnt) - (py - ph - head_r);
                    if ((ddx*ddx + ddy*ddy) <= (head_r*head_r)) begin
                        col = SKIN;
                        if (((h_cnt + v_cnt) & 4) == 0) col = rgb_add_uni(col, -1);
                        vid_rgb_d1 <= apply_flash(col, flash);
                    end
                end

                // ball
                bx = ball_x;
                by = ball_y;

                ddx = integer'(h_cnt) - (bx + 6);
                ddy = integer'(v_cnt) - (by + 6);
                if (in_pitch && (ddx*ddx + ddy*ddy) <= (BALL_R*BALL_R/2))
                    vid_rgb_d1 <= apply_flash(SHADOW, flash);

                ddx = integer'(h_cnt) - bx;
                ddy = integer'(v_cnt) - by;
                dist2 = ddx*ddx + ddy*ddy;
                if (dist2 <= (BALL_R*BALL_R)) begin
                    col = ((ddx + ddy) > 0) ? BALL_DARK : BALL_WHITE;
                    if (((h_cnt ^ v_cnt) & 3) == 0) col = rgb_add_uni(col, -2);

                    vid_rgb_d1 <= apply_flash(col, flash);
                    if (dist2 >= (BALL_R*BALL_R - 2*BALL_R))
                        vid_rgb_d1 <= apply_flash(OUTLINE, flash);
                end

                // ============================================================
                // TOP RIGHT BANNER: ROSS VIDEO + 3 effects
                // ============================================================
                wobble = (integer'({1'b0, frame_cnt[5:3]}) - 4);
                if (wobble < -3) wobble = -3;
                if (wobble >  3) wobble =  3;
                banner_l = BANNER_L0 + wobble;

                if (score_a > score_b)      col = TEAM_A;
                else if (score_b > score_a) col = TEAM_B;
                else                        col = SCORE_ACC;

                if (v_cnt >= BANNER_T && v_cnt < (BANNER_T + BANNER_H) &&
                    h_cnt >= banner_l && h_cnt < (banner_l + BANNER_W)) begin

                    // background
                    vid_rgb_d1 <= SCORE_BG;

                    // accent line (top)
                    if (v_cnt < (BANNER_T + 4))
                        vid_rgb_d1 <= col;

                    // main text
                    if (stringpix(h_cnt, v_cnt, banner_l + 18, BANNER_T + 14,
                                  "R","O","S","S"," ","V","I","D","E","O"," "," "))
                        vid_rgb_d1 <= 24'hFFFFFF;

                    // blinking LIVE badge
                    if (frame_cnt[4]) begin
                        if (h_cnt >= (banner_l + BANNER_W - 70) && h_cnt < (banner_l + BANNER_W - 18) &&
                            v_cnt >= (BANNER_T + 12)           && v_cnt < (BANNER_T + 34)) begin
                            vid_rgb_d1 <= LIVE_RED;

                            if (stringpix(h_cnt, v_cnt, banner_l + BANNER_W - 66, BANNER_T + 16,
                                          "L","I","V","E"," "," "," "," "," "," "," "," "))
                                vid_rgb_d1 <= 24'hFFFFFF;
                        end
                    end
                end

                // TOP LEFT ESPN LIVE
                if (v_cnt >= 18 && v_cnt < 48 && h_cnt >= 18 && h_cnt < 220) begin
                    vid_rgb_d1 <= SCORE_BG;
                    if (v_cnt < 22) vid_rgb_d1 <= SCORE_ACC;
                    if (h_cnt >= 165 && h_cnt < 210 && v_cnt >= 22 && v_cnt < 44) vid_rgb_d1 <= LIVE_RED;

                    if (stringpix(h_cnt, v_cnt, 28, 26, "E","S","P","N"," "," "," "," "," "," "," "," "))
                        vid_rgb_d1 <= SCORE_FG;

                    if (stringpix(h_cnt, v_cnt, 168, 26, "L","I","V","E"," "," "," "," "," "," "," "," "))
                        vid_rgb_d1 <= 24'hFFFFFF;
                end

                // SCOREBOARD (under pitch) - MM:SS
                if (v_cnt >= SB_TOP && v_cnt < SB_BOT && h_cnt >= SB_L && h_cnt < SB_R) begin
                    mm = sec / 60;
                    ss = sec % 60;

                    vid_rgb_d1 <= SCORE_BG;
                    if (v_cnt < (SB_TOP + 4)) vid_rgb_d1 <= SCORE_ACC;

                    // Score A
                    if (digit_pixel(h_cnt, v_cnt, SB_L + 40, SB_TOP + 14, score_a))
                        vid_rgb_d1 <= SCORE_FG;

                    // dash
                    if (h_cnt >= (SB_L + 90) && h_cnt < (SB_L + 115) &&
                        v_cnt >= (SB_TOP + 34) && v_cnt < (SB_TOP + 38))
                        vid_rgb_d1 <= SCORE_FG;

                    // Score B
                    if (digit_pixel(h_cnt, v_cnt, SB_L + 135, SB_TOP + 14, score_b))
                        vid_rgb_d1 <= SCORE_FG;

                    // MM
                    if (digit_pixel(h_cnt, v_cnt, SB_L + 240, SB_TOP + 14, (mm / 10)))
                        vid_rgb_d1 <= SCORE_FG;
                    if (digit_pixel(h_cnt, v_cnt, SB_L + 270, SB_TOP + 14, (mm % 10)))
                        vid_rgb_d1 <= SCORE_FG;

                    // colon
                    if (h_cnt >= (SB_L + 300) && h_cnt < (SB_L + 304) &&
                        ((v_cnt >= (SB_TOP + 24) && v_cnt < (SB_TOP + 28)) ||
                         (v_cnt >= (SB_TOP + 38) && v_cnt < (SB_TOP + 42))))
                        vid_rgb_d1 <= SCORE_FG;

                    // SS
                    if (digit_pixel(h_cnt, v_cnt, SB_L + 320, SB_TOP + 14, (ss / 10)))
                        vid_rgb_d1 <= SCORE_FG;
                    if (digit_pixel(h_cnt, v_cnt, SB_L + 350, SB_TOP + 14, (ss % 10)))
                        vid_rgb_d1 <= SCORE_FG;

                    // GOAL text
                    if (goal_anim != 0) begin
                        if (goal_anim[3] == 1'b0) begin
                            if (stringpix(h_cnt, v_cnt, SB_L + 410, SB_TOP + 16,
                                          "G","O","A","L","!"," "," "," "," "," "," "," "))
                                vid_rgb_d1 <= 24'hFFFFFF;
                        end
                    end
                end

            end else begin
                // passthrough
                vid_rgb_d1 <= vid_rgb_i;
            end

            dvh_sync_d1 <= dvh_sync_i;
        end
    end

    assign dvh_sync_o = dvh_sync_d1;
    assign vid_rgb_o  = vid_rgb_d1;

endmodule
