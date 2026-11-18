"""Convert the UCI "Online Retail.xlsx" file to raw/raw_retail.csv (requires openpyxl)."""
import csv
import datetime
import sys

import openpyxl

source, target = sys.argv[1], sys.argv[2]
sheet = openpyxl.load_workbook(source, read_only=True, data_only=True).worksheets[0]
rows = sheet.iter_rows(values_only=True)
next(rows)

with open(target, "w", newline="", encoding="utf-8") as output:
    writer = csv.writer(output)
    for invoice, stock, description, quantity, date, price, customer, country in rows:
        if isinstance(date, datetime.datetime):
            date = date.strftime("%Y-%m-%d %H:%M:%S")
        customer = "" if customer is None else int(customer)
        description = "" if description is None else description
        writer.writerow([invoice, stock, description, quantity, date, price, customer, country])
