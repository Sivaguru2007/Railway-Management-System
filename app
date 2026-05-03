from flask import Flask, render_template, request, redirect, url_for, flash
import mysql.connector
from datetime import date
import random

app = Flask(__name__)
app.secret_key = "super_secret_key" 

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",        
        password="",        
        database="railway_db"
    )

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/search_train', methods=['GET', 'POST'])
def search_train():
    trains = []
    journey_date = ""
    source = ""
    destination = ""
    
    if request.method == 'POST':
        source = request.form['source']
        destination = request.form['destination']
        journey_date = request.form.get('journey_date', date.today().strftime('%Y-%m-%d'))
        
        try:
            conn = get_db_connection()
            cursor = conn.cursor(dictionary=True)
            # Fetch trains matching the route
            query = "SELECT * FROM Train WHERE Source = %s AND Destination = %s"
            cursor.execute(query, (source, destination))
            trains = cursor.fetchall()
            
            if not trains:
                flash("No trains found for this route. Try Delhi to Mumbai!", "warning")
        except Exception as e:
            flash(f"Error: {str(e)}", "danger")
        finally:
            if 'cursor' in locals(): cursor.close()
            if 'conn' in locals(): conn.close()
            
    return render_template('search_train.html', trains=trains, journey_date=journey_date, source=source, destination=destination)

@app.route('/book_ticket', methods=['GET', 'POST'])
def book_ticket():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Capture train_id and date from URL if user clicked "Book Now" from Search page
    selected_train_id = request.args.get('train_id')
    selected_date = request.args.get('date', '')
    
    if selected_train_id:
        selected_train_id = int(selected_train_id)

    cursor.execute("SELECT * FROM Train")
    trains = cursor.fetchall()
    
    if request.method == 'POST':
        p_name = request.form['p_name']
        p_age = request.form['p_age']
        p_gender = request.form['p_gender']
        p_phone = request.form['p_phone']
        
        train_id = request.form['train_id']
        journey_date = request.form['journey_date']
        seat_type = request.form['seat_type']
        amount = request.form['amount']
        payment_mode = request.form['payment_mode']
        
        try:
            cursor.execute("INSERT INTO Passenger (Name, Age, Gender, Phone_No, Address) VALUES (%s, %s, %s, %s, 'N/A')", 
                           (p_name, p_age, p_gender, p_phone))
            passenger_id = cursor.lastrowid 
            
            seat_no = random.randint(1, 100) 
            cursor.execute("INSERT INTO Ticket (Passenger_ID, Train_ID, Journey_Date, Seat_No, Status) VALUES (%s, %s, %s, %s, 'Booked')", 
                           (passenger_id, train_id, journey_date, seat_no))
            ticket_id = cursor.lastrowid
            
            coach_no = random.choice(['A1', 'B1', 'S1', 'S2', 'C1'])
            cursor.execute("INSERT INTO Reservation (Ticket_ID, Coach_No, Seat_Type, Booking_Status) VALUES (%s, %s, %s, 'Confirmed')", 
                           (ticket_id, coach_no, seat_type))
            
            payment_date = date.today()
            cursor.execute("INSERT INTO Payment (Ticket_ID, Amount, Payment_Mode, Payment_Date) VALUES (%s, %s, %s, %s)", 
                           (ticket_id, amount, payment_mode, payment_date))
            
            conn.commit()
            flash(f"Ticket booked successfully for {p_name}! PNR Generated.", "success")
            
            cursor.close()
            conn.close()
            return redirect(url_for('view_tickets'))

        except Exception as e:
            conn.rollback()
            flash(f"Error booking ticket: {str(e)}", "danger")

    cursor.close()
    conn.close()
    return render_template('book_ticket.html', trains=trains, selected_train_id=selected_train_id, selected_date=selected_date)

@app.route('/view_tickets')
def view_tickets():
    tickets = []
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT t.Ticket_ID, p.Name, tr.Train_Name, tr.Source, tr.Destination, t.Journey_Date, t.Seat_No, t.Status,
                   r.Coach_No, r.Seat_Type, pay.Amount
            FROM Ticket t
            JOIN Passenger p ON t.Passenger_ID = p.Passenger_ID
            JOIN Train tr ON t.Train_ID = tr.Train_ID
            JOIN Reservation r ON t.Ticket_ID = r.Ticket_ID
            JOIN Payment pay ON t.Ticket_ID = pay.Ticket_ID
            ORDER BY t.Ticket_ID DESC
        """
        cursor.execute(query)
        tickets = cursor.fetchall()
    except Exception as e:
        flash(f"Error fetching tickets: {str(e)}", "danger")
    finally:
        if 'cursor' in locals(): cursor.close()
        if 'conn' in locals(): conn.close()
        
    return render_template('view_tickets.html', tickets=tickets)

@app.route('/cancel_ticket/<int:ticket_id>')
def cancel_ticket(ticket_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE Ticket SET Status = 'Cancelled' WHERE Ticket_ID = %s", (ticket_id,))
        cursor.execute("UPDATE Reservation SET Booking_Status = 'Cancelled' WHERE Ticket_ID = %s", (ticket_id,))
        conn.commit()
        flash("Ticket has been cancelled successfully.", "info")
    except Exception as e:
        conn.rollback()
        flash(f"Error cancelling ticket: {str(e)}", "danger")
    finally:
        cursor.close()
        conn.close()
    return redirect(url_for('view_tickets'))

@app.route('/delete_ticket/<int:ticket_id>')
def delete_ticket(ticket_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM Ticket WHERE Ticket_ID = %s", (ticket_id,))
        conn.commit()
        flash("Ticket record deleted permanently.", "success")
    except Exception as e:
        conn.rollback()
        flash(f"Error deleting ticket: {str(e)}", "danger")
    finally:
        cursor.close()
        conn.close()
    return redirect(url_for('view_tickets'))

if __name__ == '__main__':
    app.run(debug=True)