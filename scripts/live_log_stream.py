import os
import time
import sys
import platform

# -----------------------------------------------------------------------------
# SCRIPT: live_log_monitor.py
# PURPOSE: Monitors Vivado simulation log files for new 'ERROR' and 'WARNING' 
#          in real-time. CLEARS and REDRAWS the console ONLY when a change 
#          (new content or file reset) is detected in the log files.
# -----------------------------------------------------------------------------

# --- הגדרות ---
# הנתיב הבסיסי לתיקיית הפרויקטים של Vivado (יש לעדכן אם שונה!)
VIVADO_BASE_DIR = r"C:\VivadoProjects\Projects\VerilogRTLCourse"
LOG_FILES = ["xvlog.log", "elaborate.log"]
CHECK_INTERVAL_SEC = 1.0  
ERROR_KEYWORD = "ERROR"
WARNING_KEYWORD = "WARNING"

# קוד צבע לטרמינל
COLOR_ERROR = '\033[91m'
COLOR_WARNING = '\033[93m'
COLOR_INFO = '\033[96m'
COLOR_END = '\033[0m'
COLOR_OK = '\033[92m'

# --- משתנים גלובליים ---
# שומר את מיקום הקריאה האחרון לכל קובץ (משמש לזיהוי שינויים)
file_positions = {} 
SIM_LOG_DIR = None 

# -------------------------------
# STEP 0: פונקציות עזר וחישוב נתיבים
# -------------------------------

def clear_screen():
    """מנקה את המסך בהתאם למערכת ההפעלה (Linux/Windows)."""
    if platform.system() == "Windows":
        os.system('cls')
    else:
        os.system('clear')

def setup_paths():
    """מחשב את נתיב תיקיית הלוגים ומאתחל את המשתנה הגלובלי SIM_LOG_DIR."""
    global SIM_LOG_DIR
    try:
        scripts_dir = os.path.dirname(os.path.abspath(__file__))
        project_dir = os.path.dirname(scripts_dir)
        project_name = os.path.basename(project_dir)
        
        SIM_LOG_DIR = os.path.join(
            VIVADO_BASE_DIR, 
            project_name, 
            f"{project_name}.sim", 
            "sim_1", 
            "behav", 
            "xsim"
        )
        return project_name
    
    except Exception as e:
        print(f"{COLOR_ERROR}ERROR{COLOR_END}: Failed to set up paths: {e}")
        sys.exit(1)

# -------------------------------
# STEP 1: פונקציות קריאת נתונים
# -------------------------------

def check_for_updates_and_update_position(log_file):
    """
    בודק האם קובץ הלוג השתנה או אופס.
    מעדכן את file_positions ומחזיר True אם נמצא תוכן חדש או איפוס.
    """
    if log_file not in file_positions:
        file_positions[log_file] = 0

    full_path = os.path.join(SIM_LOG_DIR, log_file)
    if not os.path.exists(full_path):
        return False

    try:
        current_size = os.path.getsize(full_path)
        
        # 1. בדיקה לאיפוס קובץ (File Reset) - שינוי קריטי!
        if current_size < file_positions[log_file]:
            file_positions[log_file] = 0 # איפוס הפוזיציה לאפס
            return True # נחשב שינוי חיוני

        # 2. בדיקה לתוכן חדש
        if current_size > file_positions[log_file]:
            
            # אם נמצא שינוי, מעדכנים את הפוזיציה (כדי לא לאסוף את אותן שורות שוב)
            with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(file_positions[log_file])
                f.readlines() # קורא את השורות החדשות
                file_positions[log_file] = f.tell() # מעדכן את הפוזיציה
            return True # נמצא תוכן חדש

        return False # לא נמצא שינוי
    
    except Exception:
        # אם יש שגיאת קריאה, נחשיב כשינוי וננסה שוב
        return True


def get_all_current_issues_from_file(log_file):
    """
    קורא את כל קובץ הלוג מההתחלה ומחזיר את כל ה-Errors/Warnings הקיימים.
    אינו מעדכן את file_positions.
    """
    full_path = os.path.join(SIM_LOG_DIR, log_file)
    if not os.path.exists(full_path):
        return []

    found_messages = []
    
    try:
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line_stripped = line.strip()
                line_upper = line.upper()
                
                if ERROR_KEYWORD in line_upper:
                    found_messages.append(f"{COLOR_ERROR}{line_stripped}{COLOR_END}")
                elif WARNING_KEYWORD in line_upper:
                    found_messages.append(f"{COLOR_WARNING}{line_stripped}{COLOR_END}")
        
        return found_messages
    
    except Exception:
        return [f"{COLOR_ERROR}Failed to read full log content for {log_file}{COLOR_END}"]


def format_and_print_state(project_name):
    """
    קורא את המצב המלא של כל קובץ ומעצב את הפלט.
    """
    all_issues_found = {}
    total_issues = 0
    
    # איסוף כל השגיאות מכל הקבצים
    for log_file in LOG_FILES:
        issues = get_all_current_issues_from_file(log_file)
        all_issues_found[log_file] = issues
        total_issues += len(issues)

    # --- הדפסה ---
    clear_screen()
    print(f"--- 🖥️ Live Vivado Monitor (Project: {project_name}) ---")
    print(f"  (Checking every {CHECK_INTERVAL_SEC} sec | Press Ctrl+C to exit)\n")

    # אם נמצאו שגיאות/אזהרות, מציגים אותן
    if total_issues > 0:
        for log_file in LOG_FILES:
            messages = all_issues_found[log_file]
            
            # הדפסת הכותרת הויזואלית
            print(f"{COLOR_INFO}----- {log_file.upper()} -----{COLOR_END}")
            
            if messages:
                for msg in messages:
                    print(msg)
            else:
                print(f"No ERRORS/WARNINGS currently in {log_file}.")
            print("-" * 30)
            
    # אם לא נמצאו שגיאות (הקובץ נקי)
    else:
        print(f"{COLOR_OK}✅ All logs are currently clean! System ready.{COLOR_END}")
        print("\nMonitor is running... Waiting for new log entries.")
    
# -------------------------------
# STEP 3: Main Execution
# -------------------------------

if __name__ == "__main__":
    project_name = setup_paths()
    
    print(f"Project Name: {project_name}")
    print(f"Monitoring Directory: {SIM_LOG_DIR}")
    print(f"Starting initial check...")

    # קריאה ראשונית: מדפיסים את המצב הקיים מיד
    format_and_print_state(project_name)

    # לולאת הניטור הראשית
    try:
        while True:
            # 1. זיהוי שינויים
            change_detected = False
            for log_file in LOG_FILES:
                if check_for_updates_and_update_position(log_file):
                    change_detected = True
                    # אין צורך להמשיך לבדוק ברגע שנמצא שינוי
            
            # 2. הדפסה מותנית: אם זוהה שינוי (הקובץ גדל או אופס), מדפיסים את המצב המלא
            if change_detected:
                format_and_print_state(project_name)
                
            # 3. המתנה ובדיקה חוזרת
            time.sleep(CHECK_INTERVAL_SEC)
            
    except KeyboardInterrupt:
        print("\nLive monitor stopped by user.")
    except Exception as e:
        print(f"{COLOR_ERROR}An unexpected error occurred: {e}{COLOR_END}")