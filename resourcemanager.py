#!/usr/bin/env python3
"""
XRLab Events Web Server
A Flask web server that provides an interface to add events to the events.json file.
"""

import json
import os
from datetime import datetime
from flask import Flask, request, render_template, jsonify, redirect, url_for, send_from_directory
from flask_cors import CORS

app = Flask(__name__, template_folder='.')
CORS(app)

# Configuration
EVENTS_FILE = 'events.json'
VIDEOS_FILE = 'videos.json'
PORT = 5000

def load_events():
    """Load events from the JSON file."""
    try:
        with open(EVENTS_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: {EVENTS_FILE} not found. Creating empty events list.")
        return []
    except json.JSONDecodeError as e:
        print(f"Error decoding {EVENTS_FILE}: {e}")
        return []

def save_events(events):
    """Save events to the JSON file."""
    try:
        with open(EVENTS_FILE, 'w', encoding='utf-8') as f:
            json.dump(events, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving events: {e}")
        return False

def load_videos():
    """Load videos from the JSON file."""
    try:
        with open(VIDEOS_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Warning: {VIDEOS_FILE} not found. Creating empty videos list.")
        return []
    except json.JSONDecodeError as e:
        print(f"Error decoding {VIDEOS_FILE}: {e}")
        return []

def save_videos(videos):
    """Save videos to the JSON file."""
    try:
        with open(VIDEOS_FILE, 'w', encoding='utf-8') as f:
            json.dump(videos, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving videos: {e}")
        return False

def parse_links(links_text):
    """Parse links from textarea format to JSON format."""
    links = []
    if links_text.strip():
        for line in links_text.strip().split('\n'):
            line = line.strip()
            if line and ' ' in line:
                parts = line.split(' ', 1)
                name = parts[0]
                url = parts[1]
                links.append({"name": name, "url": url})
    return links

def parse_tags(tags_data, othertags_text):
    """Parse tags from checkbox and custom tags."""
    tags = []
    
    # Process checkbox tags
    if isinstance(tags_data, list):
        tags.extend(tags_data)
    elif tags_data:
        tags.append(tags_data)
    
    # Process custom tags
    if othertags_text and othertags_text.strip():
        custom_tags = [tag.strip() for tag in othertags_text.split(',') if tag.strip()]
        tags.extend(custom_tags)
    
    return tags

@app.route('/')
def index():
    """Serve the homepage."""
    return render_template('index.html')

@app.route('/events')
def events_page():
    """Serve the events display page."""
    return render_template('events.html')

@app.route('/events/new')
def new_event():
    """Serve the new event form."""
    return render_template('newevent.html')
@app.route('/videos')
def videos_page():
    """Serve the videos display page."""
    return render_template('videos.html')

@app.route('/videos/new')
def new_video():
    """Serve the new video form."""
    return render_template('newvideo.html')

@app.route('/videos.json')
def get_videos():
    """Serve the videos JSON file."""
    videos = load_videos()
    return jsonify(videos)

@app.route('/add_video', methods=['POST'])
def add_video():
    """Handle video form submission and add video to videos.json."""
    try:
        # Get form data
        form_data = request.form
        
        # Parse the video data
        video_data = {
            'title': form_data.get('title', '').strip(),
            'type': form_data.get('type', 'tech').strip(),
            'date': form_data.get('date', '').strip(),
            'duration': form_data.get('duration', '').strip(),
            'photo': form_data.get('photo', '').strip(),
            'description': form_data.get('description', '').strip(),
            'links': parse_links(form_data.get('links', '')),
            'tags': parse_tags(form_data.getlist('tags'), form_data.get('othertags', '')),
            'id': form_data.get('date', '') + form_data.get('title', '')
        }
        
        # Validate required fields
        if not video_data['title'] or not video_data['date']:
            return jsonify({'error': 'Missing required fields: title, date'}), 400
        
        # Load existing videos
        videos = load_videos()
        
        # Check if video already exists (by ID)
        existing_index = None
        for i, video in enumerate(videos):
            if video.get('id') == video_data['id']:
                existing_index = i
                break
        
        # Add or update video
        if existing_index is not None:
            videos[existing_index] = video_data
            message = "Video updated successfully"
        else:
            videos.insert(0, video_data)  # Add to beginning
            message = "Video added successfully"
        
        # Save videos
        if save_videos(videos):
            return jsonify({
                'success': True,
                'message': message,
                'video': video_data,
                'total_videos': len(videos)
            })
        else:
            return jsonify({'error': 'Failed to save videos'}), 500
            
    except Exception as e:
        print(f"Error adding video: {e}")
        return jsonify({'error': f'Server error: {str(e)}'}), 500

@app.route('/events.json')
def get_events():
    """Serve the events JSON file."""
    events = load_events()
    return jsonify(events)

@app.route('/add_event', methods=['POST'])
def add_event():
    """Handle form submission and add event to events.json."""
    try:
        # Get form data
        form_data = request.form
        
        # Parse the event data
        event_data = {
            'title': form_data.get('title', '').strip(),
            'type': form_data.get('type', 'event').strip(),
            'date': form_data.get('date', '').strip(),
            'duration': form_data.get('duration', '').strip(),
            'location': form_data.get('location', '').strip(),
            'photo': form_data.get('photo', '').strip(),
            'description': form_data.get('description', '').strip(),
            'links': parse_links(form_data.get('links', '')),
            'tags': parse_tags(form_data.getlist('tags'), form_data.get('othertags', '')),
            'id': form_data.get('date', '') + form_data.get('title', '')
        }
        
        # Validate required fields
        if not event_data['title'] or not event_data['date'] or not event_data['location']:
            return jsonify({'error': 'Missing required fields: title, date, location'}), 400
        
        # Load existing events
        events = load_events()
        
        # Check if event already exists (by ID)
        existing_index = None
        for i, event in enumerate(events):
            if event.get('id') == event_data['id']:
                existing_index = i
                break
        
        # Add or update event
        if existing_index is not None:
            events[existing_index] = event_data
            message = "Event updated successfully"
        else:
            events.insert(0, event_data)  # Add to beginning
            message = "Event added successfully"
        
        # Save events
        if save_events(events):
            return jsonify({
                'success': True,
                'message': message,
                'event': event_data,
                'total_events': len(events)
            })
        else:
            return jsonify({'error': 'Failed to save events'}), 500
            
    except Exception as e:
        print(f"Error adding event: {e}")
        return jsonify({'error': f'Server error: {str(e)}'}), 500

@app.route('/img/<path:filename>')
def serve_img(filename):
    """Serve image files from img directory."""
    return send_from_directory('img', filename)

@app.route('/static/<path:filename>')
def static_files(filename):
    """Serve static files."""
    return send_from_directory('.', filename)

if __name__ == '__main__':
    print(f"Starting XRLab Manager Server on port {PORT}")
    print(f"Open http://localhost:{PORT} - Homepage")
    print(f"Open http://localhost:{PORT}/events - Events list")
    print(f"Open http://localhost:{PORT}/events/new - Add events")
    print(f"Open http://localhost:{PORT}/videos - Videos list")
    print(f"Open http://localhost:{PORT}/videos/new - Add videos")
    
    # Check if events.json exists
    if not os.path.exists(EVENTS_FILE):
        print(f"Warning: {EVENTS_FILE} not found. It will be created when the first event is added.")
    
    app.run(host='0.0.0.0', port=PORT, debug=True)
