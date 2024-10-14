from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit
#from flask_talisman import Talisman
import subprocess
import threading
import time

app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app)
#Talisman(app, content_security_policy=None)

# Global variable to store the subprocess
process = None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/submit_content', methods=['POST'])
def submit_content():
    content = request.form['content']
    try:
        with open('tasks/input_file.txt', 'w') as f:
            f.write(content)
        return jsonify({"status": "Content written to file"})
    except Exception as e:
        app.logger.error(f"Error writing content to file: {e}")
        return jsonify({"status": "Error", "message": str(e)}), 500

@app.route('/start_script', methods=['POST'])
def start_script():
    global process
    if process is None or process.poll() is not None:  # Check if the process is None or has exited
        try:
            print("Starting script...")
            process = subprocess.Popen(['stdbuf', '-oL', '/bin/bash', 'mytd_flask.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, universal_newlines=True)
            threading.Thread(target=read_output).start()
            return jsonify({"status": "Script started"})
        except Exception as e:
            app.logger.error(f"Error starting script: {e}")
            return jsonify({"status": "Error", "message": str(e)}), 500
    else:
        return jsonify({"status": "Script already running"})

@app.route('/send_input', methods=['POST'])
def send_input():
    global process
    if process is not None and process.poll() is None:  # Check if the process is still running
        try:
            user_input = request.form['input']
            print(f"Sending input: {user_input}")
            process.stdin.write(user_input + "\n")
            process.stdin.flush()
            return jsonify({"status": ""})
        except Exception as e:
            app.logger.error(f"Error sending input: {e}")
            return jsonify({"status": "Error", "message": str(e)}), 500
    else:
        return jsonify({"status": "No script running or script has terminated"})

def read_output():
    global process
    try:
        with app.app_context():
            while process.poll() is None:
                output = process.stdout.readline()
                if output:
                    #print(f"Output: {output}")
                    socketio.emit('new_output', {'output': output})
            print("Script has exited.")
            socketio.emit('new_output', {'output': "Script has exited.\n"})
    except Exception as e:
        app.logger.error(f"Error reading output: {e}")

def monitor_process():
    global process
    while True:
        if process is not None and process.poll() is not None:  # Check if the process has exited
            print("Process has exited, restarting...")
            with app.app_context():
                start_script()
        time.sleep(5)  # Check every 5 seconds

if __name__ == '__main__':
    threading.Thread(target=monitor_process, daemon=True).start()
    #socketio.run(app, debug=True, host='0.0.0.0', port=8001)
    #socketio.run(app, debug=True, host='0.0.0.0', port=8001, ssl_context=('cert.pem', 'key.pem'))
    socketio.run(app, debug=True, host='0.0.0.0', port=8001, ssl_context=('server.crt', 'server.key'))
