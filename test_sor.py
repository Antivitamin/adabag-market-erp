import pymssql

conn = pymssql.connect(server=r"SERVER-AVM\SQLEXPRESS", database="INTER_BOS", as_dict=True)
cur = conn.cursor()
cur.execute("""
SELECT TOP 15 Kasa_No, CASHTOTAL, CREDITTOTAL, CANCELTOTAL, Toplam 
FROM BELGE WITH (NOLOCK) 
WHERE CONVERT(VARCHAR(10), BELGETARIH, 120) = '2026-10-22' 
  AND Kasa_No = 1 
  AND (CREDITTOTAL > 0 OR CASHTOTAL > 0)
ORDER BY Toplam DESC
""")
for r in cur.fetchall():
    print(f"Kasa: {r['Kasa_No']} | Nakit: {r['CASHTOTAL']} | POS: {r['CREDITTOTAL']} | Toplam: {r['Toplam']}")
conn.close()
