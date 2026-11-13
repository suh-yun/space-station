// 대략적으로 만듬 top.v 완성 후에 다시 수정해야 함


`timescale 1ns / 1ps

module tb_top;

    // 1. 테스트벤치 제어 신호 입력
    reg clk;
    reg rst;
    reg start;

    // 2. 최상위 모듈(top) 출력 모니터링 와이어
    wire [15:0] led;
    wire [7:0]  an;
    wire [6:0]  seg;
    wire        dp;
    wire        done;
    wire        success;

    // 3. Top 모듈 인스턴스화 (UUT)
    // ※ 프로젝트 내 top 모듈의 포트 이름에 맞춰 일부 수정이 필요할 수 있습니다.
    top u_top (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .led     (led),
        .an      (an),
        .seg     (seg),
        .dp      (dp),
        .done    (done),
        .success (success)
    );

    // 4. 클록 생성 (100MHz 기준, 주기 10ns)
    always #5 clk = ~clk;

    // 5. 시나리오 실행 
    initial begin
        // 초기화
        clk   = 0;
        rst   = 1;
        start = 0;

        // 100ns 동안 리셋 유지
        #100;
        rst = 0;
        
        #20;
        // 시뮬레이션 시작 (START 버튼 누름 효과)
        start = 1;
        #10;
        start = 0;

        // 타임루프들과 8시간 단계들이 충분히 진행될 수 있도록 대기 
        // (클록 분주기 속도에 따라 시뮬레이션 시간 조절 필요)
        #10000;

        // 테스트 종료
        $finish;
    end

    // 6. 시뮬레이션 중 주요 상태 변화 콘솔 출력
    initial begin
        $monitor("Time=%0t ns | DONE=%b | SUCCESS=%b | LED=16'h%h", 
                 $time, done, success, led);
    end

endmodule
