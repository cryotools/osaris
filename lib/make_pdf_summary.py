from reportlab.pdfgen import canvas
from reportlab.lib.units import inch, cm

c = canvas.Canvas('ex.pdf')
c.drawImage('ar.jpg', 0, 0, 10*cm, 10*cm)
c.showPage()
c.save()
