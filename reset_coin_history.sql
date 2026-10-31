-- =====================================================================================================================
-- 파일명 : reset_coin_history.sql
-- 작성일 : 2026-10-31
-- 기능   : 코인 거래 이력 초기화(회원 전체) — 거래 · 입출금 · 봇 진행 상태 · 운용보고서 글 · 투자금 변경 이력 · 알림 기록만 지움
--          · 남기는 것 : 캔들(5초봉 · 1분 · 5분 · 10분 · 1시간 · 일봉) · 급등/실시간 학습 자료 · 학습 모델 · 사이트 코인 설정(coin_site_*)
--                        회원 설정(업비트 API 키 · 코인별 운용금액/라인/전략 · 봇 판단값 · 반등 매매 설정 · 화면 · 보고서 설정)
--          · 안전장치 : 실거래로 아직 보유 중(또는 매수 중 · 확인 필요)인 줄이 1개라도 있으면 아무것도 지우지 않음(@open > 0)
--          · 표 이름 접두어는 ph_ 기준 — 사이트 접두어가 다르면 ph_ 를 모두 바꿔서 실행
-- 순서   : ① 서버 실행(코인 봇 서버 프로그램)을 멈춤 → ② 아래 [1단계] 조회만 실행해 0 인지 확인 → ③ 파일 전체 실행 → ④ 서버 실행 다시 켬
-- =====================================================================================================================

-- [1단계] 실거래 보유 중인 줄 확인 — 결과가 0 이 아니면 그 회원 코인을 업비트에서 먼저 정리(거래이력 [시장가 매도] 또는 업비트 앱)
SELECT 'auto' AS `kind`, `mem_id`, `market`, `qty`                                                                      -- 자동매매 보유 라인
    FROM `ph_mod_coin_trade_log`
    WHERE `mode` = 'real' AND `side` = 'buy' AND `status` = 'open'
UNION ALL
SELECT 'rebound', `mem_id`, `market`, `qty`                                                                             -- 반등(게시글 · 실시간) 보유 · 매수 중 · 확인 필요
    FROM `ph_mod_coin_rebound_pos`
    WHERE `mode` = 'real' AND `state` IN ('open', 'buying', 'error')
UNION ALL
SELECT 'limit', `mem_id`, `market`, `qty`                                                                               -- 걸어 둔 지정가 주문
    FROM `ph_mod_coin_limit_order`
    WHERE `mode` = 'real' AND `status` = 'open';

-- [2단계] 안전장치 값 — 위 줄 수(0 일 때만 아래 DELETE 가 지움)
SET @open = (
    SELECT
        (SELECT COUNT(*) FROM `ph_mod_coin_trade_log` WHERE `mode` = 'real' AND `side` = 'buy' AND `status` = 'open')
      + (SELECT COUNT(*) FROM `ph_mod_coin_rebound_pos` WHERE `mode` = 'real' AND `state` IN ('open', 'buying', 'error'))
      + (SELECT COUNT(*) FROM `ph_mod_coin_limit_order` WHERE `mode` = 'real' AND `status` = 'open')
);
SELECT IF(@open = 0, '실거래 보유 줄 없음 — 초기화 진행', CONCAT('실거래 보유 줄 ', @open, '개 — 아무것도 지우지 않음')) AS `확인`;

-- [3단계] 거래 · 입출금 이력(표)
DELETE FROM `ph_mod_coin_trade_log`     WHERE @open = 0;                                                                -- 자동매매 거래이력(매수 · 매도 · 손익)
DELETE FROM `ph_mod_coin_rebound_pos`   WHERE @open = 0;                                                                -- 반등 단기 매매 기록(게시글 · 실시간 · 건너뜀 포함)
DELETE FROM `ph_mod_coin_fill`          WHERE @open = 0;                                                                -- 업비트 실제 체결(거래이력 답글 줄)
DELETE FROM `ph_mod_coin_fund_flow`     WHERE @open = 0;                                                                -- 입출금 기록(업비트 입금 · 출금 나눔)
DELETE FROM `ph_mod_coin_limit_order`   WHERE @open = 0;                                                                -- 지정가 수동 주문 기록
DELETE FROM `ph_mod_coin_tick_notice`   WHERE @open = 0;                                                                -- 매매 알림 기록

-- [4단계] 봇 진행 상태(표 — 회원 · 코인별 고점 · 정지 · 마지막 매도 등)
DELETE FROM `ph_mod_coin_accum_state`      WHERE @open = 0;                                                             -- 코인 적립 상태
DELETE FROM `ph_mod_coin_grid_trend_state` WHERE @open = 0;                                                             -- 그리드 추세 상태
DELETE FROM `ph_mod_coin_hybrid_state`     WHERE @open = 0;                                                             -- 하이브리드 상태
DELETE FROM `ph_mod_coin_hyacc_state`      WHERE @open = 0;                                                             -- 하이브리드 적립 상태
DELETE FROM `ph_mod_coin_peak_state`       WHERE @open = 0;                                                             -- 고점 상태
DELETE FROM `ph_mod_coin_reserve_state`    WHERE @open = 0;                                                             -- 예비 라인 상태
DELETE FROM `ph_mod_coin_run_lock`         WHERE @open = 0;                                                             -- 회원 실행 잠금(남은 잠금)

-- [5단계] 회원 상태 · 기록(ph_config — 설정 종류는 지우지 않음)
DELETE FROM `ph_config`
    WHERE @open = 0 AND `cfg_type` IN (
        'coin_mem_fund',                                                                                                -- 운용자금 조정 상태(봇 코인별 · 반등 기준 자금 · 입출금 나눔)
        'coin_mem_flow',                                                                                                -- 입출금 확인 상태
        'coin_mem_ledger',                                                                                              -- 실거래 잔액 맞춤 장부
        'coin_mem_guard',                                                                                               -- 큰 추세 보호 판단
        'coin_mem_lossrb',                                                                                              -- 손절 뒤 되사기
        'coin_mem_peak',                                                                                                -- 되돌림 익절 라인 고점
        'coin_mem_range',                                                                                               -- 횡보장 반등 추매
        'coin_mem_rebuy',                                                                                               -- 눌림 재매수 기준가
        'coin_mem_target',                                                                                              -- 라인 익절 예상가
        'coin_mem_timer',                                                                                               -- 봇 판단 시각 · 재진입 대기
        'coin_mem_v7',                                                                                                  -- 7국면 상태
        'coin_mem_xfer',                                                                                                -- 봇 넘기기 진행
        'coin_xfer_log',                                                                                                -- 봇 넘기기 기록
        'coin_mem_rbt_st',                                                                                              -- 반등 처리 상태(마지막 신호 · 오늘 산 표시)
        'coin_mem_report_state',                                                                                        -- 운용보고서 보낸 기록
        'coin_mem_report_stat',                                                                                         -- 봇 동작 기록(보고서용)
        'coin_mem_caplog'                                                                                               -- 투자금(운용금액) 변경 이력
    );

-- [6단계] 운용보고서 게시판(coin_report) 글 · 댓글 · 첨부 기록
DELETE FROM `ph_mod_board_cmt_coin_report`  WHERE @open = 0;                                                            -- 댓글
DELETE FROM `ph_mod_board_data_coin_report` WHERE @open = 0;                                                            -- 글
DELETE FROM `ph_mod_board_files` WHERE @open = 0 AND `id` = 'coin_report';                                              -- 첨부 기록(파일은 data 폴더에 남으면 직접 지움)

-- [7단계] 결과 확인 — 모두 0 이면 끝(@open 이 0 이 아니었으면 그대로 남아 있음)
SELECT
    (SELECT COUNT(*) FROM `ph_mod_coin_trade_log`)   AS `거래이력`,                                                     -- 자동매매
    (SELECT COUNT(*) FROM `ph_mod_coin_rebound_pos`) AS `반등기록`,                                                     -- 반등
    (SELECT COUNT(*) FROM `ph_mod_coin_fund_flow`)   AS `입출금`,                                                       -- 입출금
    (SELECT COUNT(*) FROM `ph_mod_board_data_coin_report`) AS `보고서글`,                                               -- 보고서 글
    (SELECT COUNT(*) FROM `ph_config` WHERE `cfg_type` IN ('coin_mem_fund', 'coin_mem_flow', 'coin_mem_caplog', 'coin_mem_rbt_st')) AS `회원상태`, -- 회원 상태
    (SELECT COUNT(*) FROM `ph_mod_coin_lrn_c60`)     AS `1시간봉(남김)`,                                                -- 캔들 그대로인지
    (SELECT COUNT(*) FROM `ph_config` WHERE `cfg_type` = 'coin_mem_api') AS `API키(남김)`;                              -- 설정 그대로인지
