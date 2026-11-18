-- FPVR online database: MySQL 8.4, InnoDB.
-- Run against an empty database selected by the deployment administrator.
-- Quest clients access an HTTPS application service, never MySQL directly.

CREATE TABLE player_account (
    account_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(64) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (account_id),
    UNIQUE KEY uq_account_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE course_level (
    level_id VARCHAR(64) NOT NULL,
    level_name VARCHAR(100) NOT NULL,
    environment_name VARCHAR(100) NOT NULL,
    difficulty ENUM('introductory', 'intermediate', 'advanced') NOT NULL,
    PRIMARY KEY (level_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;

CREATE TABLE flight_result (
    result_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    account_id BIGINT UNSIGNED NOT NULL,
    level_id VARCHAR(64) NOT NULL,
    source_local_player_id CHAR(36) CHARACTER SET ascii
        COLLATE ascii_bin NOT NULL,
    completed_at DATETIME(3) NOT NULL COMMENT 'UTC completion time',
    total_time_seconds DECIMAL(12,3) NOT NULL,
    crash_count INT UNSIGNED NOT NULL,
    score INT UNSIGNED NOT NULL,
    rating ENUM('Gold', 'Silver', 'Bronze', 'Needs Improvement') NOT NULL,
    accepted_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (result_id),
    CONSTRAINT fk_result_account FOREIGN KEY (account_id)
        REFERENCES player_account (account_id) ON DELETE RESTRICT,
    CONSTRAINT fk_result_level FOREIGN KEY (level_id)
        REFERENCES course_level (level_id) ON DELETE RESTRICT,
    CONSTRAINT ck_result_time CHECK (total_time_seconds >= 0),
    CONSTRAINT ck_result_score CHECK (score <= 1000),
    KEY ix_level_ranking
        (level_id, score DESC, total_time_seconds, completed_at, result_id),
    KEY ix_account_history (account_id, completed_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_ci;
