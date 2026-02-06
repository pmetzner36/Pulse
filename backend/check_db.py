import sqlite3

conn = sqlite3.connect('pulse.db')
cursor = conn.execute('SELECT COUNT(*) FROM cities')
count = cursor.fetchone()[0]
print(f'Cities in database: {count}')

if count > 0:
    cursor = conn.execute('SELECT id, name FROM cities LIMIT 5')
    for row in cursor.fetchall():
        print(f'  {row[0]}: {row[1]}')
else:
    print('No cities found! Database needs to be reseeded.')

conn.close()
