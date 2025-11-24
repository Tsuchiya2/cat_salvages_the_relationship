#!/bin/bash
# Rollback Script: MySQL 8 to PostgreSQL
#
# This script reverts the database configuration from MySQL 8 back to PostgreSQL
# Used in case of migration failure or critical issues detected post-migration
#
# Usage:
#   ./scripts/rollback_to_postgresql.sh
#
# Prerequisites:
#   - PostgreSQL backup must be available and accessible
#   - config/database.yml.postgresql_backup must exist
#   - Gemfile.postgresql_backup must exist
#
# Exit codes:
#   0 - Successful rollback
#   1 - Rollback failed

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RAILS_ENV="${RAILS_ENV:-production}"
APP_DIR="${APP_DIR:-/Users/yujitsuchiya/cat_salvages_the_relationship}"
BACKUP_CONFIG="config/database.yml.postgresql_backup"
BACKUP_GEMFILE="Gemfile.postgresql_backup"
ROLLBACK_LOG="tmp/rollback_$(date +%Y%m%d_%H%M%S).log"

# Function to print messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$ROLLBACK_LOG"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}" | tee -a "$ROLLBACK_LOG"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}" | tee -a "$ROLLBACK_LOG"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}" | tee -a "$ROLLBACK_LOG"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check if backup files exist
    if [ ! -f "$BACKUP_CONFIG" ]; then
        log_error "Backup database configuration not found: $BACKUP_CONFIG"
        exit 1
    fi
    log_success "Found database configuration backup"

    if [ ! -f "$BACKUP_GEMFILE" ]; then
        log_error "Backup Gemfile not found: $BACKUP_GEMFILE"
        exit 1
    fi
    log_success "Found Gemfile backup"

    # Check if bundle command exists
    if ! command_exists bundle; then
        log_error "Bundler not found. Please install: gem install bundler"
        exit 1
    fi
    log_success "Bundler found"

    # Check if PostgreSQL client exists
    if ! command_exists psql; then
        log_warning "PostgreSQL client (psql) not found. Connection test will be skipped."
    else
        log_success "PostgreSQL client found"
    fi
}

# Function to stop the application
stop_application() {
    log "Stopping application..."

    # Try multiple methods to stop the app
    if command_exists systemctl; then
        sudo systemctl stop reline-app 2>/dev/null || log_warning "systemctl stop failed, trying other methods..."
    fi

    if [ -f "tmp/pids/server.pid" ]; then
        kill -TERM $(cat tmp/pids/server.pid) 2>/dev/null || log_warning "Could not stop via PID file"
        rm -f tmp/pids/server.pid
    fi

    # Kill any remaining Puma processes
    pkill -f puma 2>/dev/null || log_warning "No Puma processes found"

    sleep 2
    log_success "Application stopped"
}

# Function to backup current configuration
backup_current_config() {
    log "Backing up current MySQL configuration..."

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp config/database.yml "config/database.yml.mysql_backup_$TIMESTAMP"
    cp Gemfile "Gemfile.mysql_backup_$TIMESTAMP"

    log_success "Current configuration backed up with timestamp: $TIMESTAMP"
}

# Function to restore PostgreSQL configuration
restore_postgresql_config() {
    log "Restoring PostgreSQL configuration..."

    # Restore database.yml
    cp "$BACKUP_CONFIG" config/database.yml
    log_success "Restored config/database.yml"

    # Restore Gemfile
    cp "$BACKUP_GEMFILE" Gemfile
    log_success "Restored Gemfile"
}

# Function to install dependencies
install_dependencies() {
    log "Installing PostgreSQL dependencies..."

    # Remove Gemfile.lock to force fresh install
    if [ -f "Gemfile.lock" ]; then
        mv Gemfile.lock "Gemfile.lock.mysql_backup_$(date +%Y%m%d_%H%M%S)"
    fi

    # Install gems
    if [ "$RAILS_ENV" = "production" ]; then
        bundle install --deployment --without development test
    else
        bundle install
    fi

    log_success "Dependencies installed"
}

# Function to verify PostgreSQL connection
verify_postgresql_connection() {
    log "Verifying PostgreSQL connection..."

    # Try to connect using Rails
    if bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name" 2>&1 | grep -q "Pg"; then
        log_success "PostgreSQL connection verified"
        return 0
    else
        log_error "Failed to verify PostgreSQL connection"
        return 1
    fi
}

# Function to start the application
start_application() {
    log "Starting application..."

    # Try multiple methods to start the app
    if command_exists systemctl; then
        sudo systemctl start reline-app 2>/dev/null && log_success "Started via systemctl" && return 0
    fi

    # Manual start for development
    if [ "$RAILS_ENV" != "production" ]; then
        bundle exec rails server -d -e "$RAILS_ENV" && log_success "Started Rails server in daemon mode" && return 0
    fi

    log_warning "Could not automatically start application. Please start manually."
}

# Function to verify application health
verify_application_health() {
    log "Verifying application health..."

    # Wait for app to start
    sleep 5

    # Check if app is responding (if health endpoint exists)
    if command_exists curl; then
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log_success "Application health check passed"
            return 0
        else
            log_warning "Health check failed or endpoint not available"
        fi
    fi

    # Check if processes are running
    if pgrep -f puma >/dev/null 2>&1; then
        log_success "Application process is running"
        return 0
    else
        log_warning "Application process not detected"
        return 1
    fi
}

# Main rollback procedure
main() {
    echo "================================================================================"
    echo "                    DATABASE ROLLBACK TO POSTGRESQL                           "
    echo "================================================================================"
    echo "Environment: $RAILS_ENV"
    echo "Log file: $ROLLBACK_LOG"
    echo "Start time: $(date)"
    echo "================================================================================"
    echo

    # Ensure tmp directory exists
    mkdir -p tmp

    START_TIME=$(date +%s)

    # Execute rollback steps
    check_prerequisites
    echo

    log_warning "Starting rollback in 5 seconds... Press Ctrl+C to cancel"
    sleep 5
    echo

    stop_application
    backup_current_config
    restore_postgresql_config
    install_dependencies

    echo
    log "Verifying database configuration..."
    if verify_postgresql_connection; then
        log_success "PostgreSQL connection successful"
    else
        log_error "PostgreSQL connection verification failed"
        log_error "Please check database credentials and PostgreSQL server status"
        exit 1
    fi

    echo
    start_application
    sleep 3

    echo
    verify_application_health

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo
    echo "================================================================================"
    log_success "ROLLBACK COMPLETED SUCCESSFULLY"
    echo "================================================================================"
    log "Duration: ${DURATION} seconds"
    log "Application is now running on PostgreSQL"
    log "MySQL 8 configuration backed up for future reference"
    log "Next steps:"
    log "  1. Verify application functionality"
    log "  2. Check application logs for errors"
    log "  3. Monitor database queries"
    log "  4. Investigate root cause of rollback"
    echo "================================================================================"

    exit 0
}

# Error handler
error_handler() {
    log_error "Rollback failed at line $1"
    log_error "Please check the log file: $ROLLBACK_LOG"
    exit 1
}

trap 'error_handler $LINENO' ERR

# Run main procedure
main "$@"
