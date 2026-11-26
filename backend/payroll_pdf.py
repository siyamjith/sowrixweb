"""Private, employee-only PDF of an already-finalized payroll record.

This is a preview document, NOT an issued statutory payslip, tax declaration,
salary transfer, or proof of payment. The gateway MUST call employee-scoped
sowrix_r464_my_payslip under the actual employee session before rendering.
"""
from __future__ import annotations
from io import BytesIO
from decimal import Decimal, InvalidOperation
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4


def plain(value,limit=150):
    # Core fonts support Latin-1 only; fall back rather than corrupt the PDF.
    return str(value if value is not None else '-').encode('latin-1','replace').decode('latin-1')[:limit]


def rupees(value):
    try:return 'INR {:,.2f}'.format(Decimal(str(value or 0)))
    except (ValueError,InvalidOperation):return 'Verify with HR'


def render_preview(record:dict)->bytes:
    if not isinstance(record,dict):raise ValueError('Payroll record is unavailable')
    if str(record.get('status','')).lower() not in ('finalized','paid'):
        raise ValueError('Only already-finalized employee records can be previewed')
    if not record.get('period') or not record.get('employee_code'):
        raise ValueError('Employee identity and period required')
    out=BytesIO();pdf=canvas.Canvas(out,pagesize=A4,pageCompression=1)
    width,height=A4
    pdf.setTitle('SOWRIX Private Payroll Record Preview')
    pdf.setAuthor('SOWRIX TECHNOLOGIES')
    pdf.setFillColorRGB(.07,.22,.53);pdf.rect(0,height-115,width,115,stroke=0,fill=1)
    pdf.setFillColorRGB(1,1,1);pdf.setFont('Helvetica-Bold',21);pdf.drawString(45,height-59,'SOWRIX TECHNOLOGIES')
    pdf.setFont('Helvetica',12);pdf.drawString(45,height-83,'Private employee payroll record preview')
    pdf.setFillColorRGB(.12,.22,.4)
    pdf.setFont('Helvetica-Bold',12);pdf.drawString(45,height-143,'NOT A STATUTORY PAYSLIP OR PAYMENT CONFIRMATION')
    pdf.setFont('Helvetica',10);pdf.drawString(45,height-162,'Review payroll taxes, legal deductions and salary settlement with authorized HR.')
    entries=[('Employee',plain(record.get('employee_name'))),('Employee code',plain(record.get('employee_code'))),
             ('Payroll period',plain(record.get('period'))),('Basic',rupees(record.get('basic'))),
             ('Allowances',rupees(record.get('allowances'))),('Deductions',rupees(record.get('deductions'))),
             ('Net',rupees(record.get('net'))),('Record status',plain(record.get('status')))]
    y=height-212
    for label,value in entries:
        pdf.setFillColorRGB(.1,.25,.55);pdf.setFont('Helvetica-Bold',11);pdf.drawString(50,y,plain(label,50))
        pdf.setFillColorRGB(.09,.15,.28);pdf.setFont('Helvetica',11);pdf.drawString(235,y,plain(value,65))
        pdf.setStrokeColorRGB(.81,.86,.94);pdf.line(45,y-12,width-45,y-12)
        y-=48
    pdf.setFont('Helvetica',9);pdf.setFillColorRGB(.35,.40,.48)
    pdf.drawString(45,68,'Access restricted to the employee named above. Do not distribute publicly.')
    pdf.drawString(45,51,'This preview does not update, approve or settle payroll.')
    pdf.showPage();pdf.save();return out.getvalue()
