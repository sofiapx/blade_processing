import processing.serial.*;
import controlP5.*;

ControlP5 cp5;
Serial myPort;
PrintWriter output;
PFont font;

int marcasIniciales = 0;

float[] detecciones = {0, 0, 0};
float[] umbrales = {0, 0, 0};
float[] tolerancias = {0, 0, 0};

int idxDet = 0;
int idxUmb = 0;
int idxTol = 0;

color colorGrabando = color(200, 0, 0);     // rojo
color colorNormal = color(100, 180, 100);   // verde

int lf = 10;
String myString = null;
int heightVAS = 0;
boolean fileSelectedyet = false;
boolean isRecording = false;

Button recordButton;
Button markButton;

int windowSeconds = 5;
int sampleRate = 200;                 // igual a frameRate
int maxPoints = windowSeconds * sampleRate;

float[] buffer = new float[maxPoints];
int bufferIndex = 0;
boolean bufferFull = false;


void setup() {
  size(700, 460);
  frameRate(60);    // Optional: limit frame rate for stable drawing
  font = createFont("Segoe UI", 14);
  textFont(font);   // se aplica a todo el texto de Processing
  
  // Crear interfaz de usuario
  cp5 = new ControlP5(this);

  // Botón de grabar/detener
  recordButton = cp5.addButton("toggleRecording")
     .setLabel("GRABAR")
     .setPosition(width - 130, 10)
     .setSize(120, 60);
  
  //restart soft
  cp5.addButton("restartSketch")
   .setLabel("REINICIAR")
   .setPosition(width - 130, 170)
   .setSize(120, 60)
   .getCaptionLabel().setFont(font);

  // Botón de marca
  markButton = cp5.addButton("sendMark")
     .setLabel("AGREGAR MARCA")
     .setPosition(width - 130, 90)
     .setSize(120, 60);
     
  recordButton.getCaptionLabel().setFont(font);
  markButton.getCaptionLabel().setFont(font);
  recordButton.setColorBackground(colorNormal);
  recordButton.setColorActive(color(255, 0, 0));
  recordButton.setColorForeground(colorNormal);
  // Selección de puerto serie
  String[] portList = Serial.list();
  if (portList.length == 0) {
    println("No hay puertos disponibles.");
    exit();
  }

  String selectedPort = (String) javax.swing.JOptionPane.showInputDialog(
    null,
    "Selecciona el puerto serie:",
    "Puerto Serie",
    javax.swing.JOptionPane.QUESTION_MESSAGE,
    null,
    portList,
    portList[0]
  );

  if (selectedPort == null) {
    println("No se seleccionó puerto.");
    exit();
  }

  myPort = new Serial(this, selectedPort, 115200);
  myPort.clear();
  myPort.bufferUntil('\n');

  selectInput("Selecciona un archivo para guardar:", "fileSelected");

  prepareExitHandler();
}

void draw() {
  background(151);

  if (!fileSelectedyet) {
    fill(255);
    textAlign(CENTER, CENTER);
    text("Esperando selección de archivo...", width/2, height/2);
    return;
  }

   while (myPort.available() > 0) {
    myString = myPort.readStringUntil('\n');
    if (myString != null) {
      myString = trim(myString);

       try {
  if (myString.equalsIgnoreCase("marca inicial")) {
    marcasIniciales++;
    if (isRecording && output != null) {
      output.println("marca inicial\t" + millis());
      output.flush();
    }
  }
  
  else if (myString.equalsIgnoreCase("marca final")) { // Nueva marca agregada
    if (isRecording && output != null) {
      output.println("marca final\t" + millis()); // Formato idéntico a la inicial
      output.flush();
    }
  }
  
//  else if (myString.equalsIgnoreCase("marca deteccion")) {
//  if (idxDet < 3) {
//    detecciones[idxDet] = buffer[(bufferIndex - 1 + maxPoints) % maxPoints];
//    if (isRecording && output != null) output.println("deteccion_" + (idxDet+1) + "\t" + detecciones[idxDet] + "\t" + millis());
//    idxDet++;
//  }
//}
else if (myString.equalsIgnoreCase("marca umbral")) {
  if (idxUmb < 3) {
    umbrales[idxUmb] = buffer[(bufferIndex - 1 + maxPoints) % maxPoints];
    if (isRecording && output != null) output.println("umbral_" + (idxUmb+1) + "\t" + umbrales[idxUmb] + "\t" + millis());
    idxUmb++;
  }
}
else if (myString.equalsIgnoreCase("marca tolerancia")) {
  if (idxTol < 3) {
    tolerancias[idxTol] = buffer[(bufferIndex - 1 + maxPoints) % maxPoints];
    if (isRecording && output != null) output.println("tolerancia_" + (idxTol+1) + "\t" + tolerancias[idxTol] + "\t" + millis());
    idxTol++;
  }
}
  else {
    // parsear el número de fuerza 
    float value = float(myString.split(",")[0]);
    if (!Float.isNaN(value)) {
      buffer[bufferIndex] = value;
      bufferIndex = (bufferIndex + 1) % maxPoints;
      if (bufferIndex == 0) bufferFull = true;
      if (isRecording && output != null) {
        // Agregamos la hora del sistema al final para tu columna extra
        //output.println(value + "," + millis() + "," + hour() + ":" + minute() + ":" + second());
        output.println(value + ","+float(myString.split(",")[1]) +","+ millis()); // capturo el tiempo que se manda desde arduino y agrego el de este programa para chequear delays
      }
    }
  }
} catch (Exception e) {
        println("Error parseando: " + myString);
      }
    }
  }
  // Dibuja todo UNA SOLA VEZ por frame, con el último valor del buffer
  float lastValue = buffer[(bufferIndex - 1 + maxPoints) % maxPoints];

  fill(0);
textAlign(CENTER, CENTER);
textSize(140); // Un poco más pequeño para dar aire
text(nf(lastValue, 1, 4), width/2 - 50, height/2-50); // Antes era height/2 - 100

// --- Dibujo de la Tabla de Umbrales (Arriba) ---
textSize(18);
textAlign(LEFT, TOP);
fill(60); // Gris oscuro

// Fila de Umbral
text("Umbral:", 20, 75);
for(int i=0; i<3; i++) text(nf(umbrales[i], 1, 4), 130 + (i*90), 75);

// Fila de Tolerancia
text("Tolerancia:", 20, 105);
for(int i=0; i<3; i++) text(nf(tolerancias[i], 1, 4), 130 + (i*90), 105);

// --- Títulos de Columnas ---
fill(100);
textSize(12);
text("Medicion 1", 130, 30);
text("Medicion 2", 220, 30);
text("Medicion 3", 310, 30);
  
  drawPlot();
}

// Botón GRABAR/DETENER
void toggleRecording() {
  if (!fileSelectedyet) return;

  isRecording = !isRecording;

  if (isRecording) {
    recordButton.setLabel("DETENER");
    recordButton.setColorBackground(colorGrabando);
    recordButton.setColorForeground(colorGrabando);
    println("Grabación iniciada.");
  } else {
    recordButton.setLabel("GRABAR");
    recordButton.setColorBackground(colorNormal);
    recordButton.setColorForeground(colorNormal);
    output.flush(); 
    println("Grabación detenida.");
  }
}

// Botón AGREGAR MARCA
void sendMark() {
  if (isRecording && fileSelectedyet) {
    output.println("mark\t" + millis());
    println("Marca agregada desde botón.");
  }
}

// Presionar tecla "m" agrega marca
void keyPressed() {
  if (isRecording && fileSelectedyet && key == 'm') {
    output.println("mark\t" + millis());
    println("Marca agregada desde teclado.");
  }
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Cancelado.");
    exit();
  } else {
    output = createWriter(selection.getAbsolutePath()); 
    fileSelectedyet = true;
    println("Guardando en: " + selection.getAbsolutePath());
  }
}

private void prepareExitHandler() {
  Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
    public void run () {
      if (output != null) {
        output.flush();  
        output.close();  
      }
    }
  }));
}

void drawPlot() {
  
  int plotX = 50;
  int plotY = height - 180;
  int plotW = width - 200;
  int plotH = 120;

  // Marco
  stroke(0);
  noFill();
  rect(plotX, plotY, plotW, plotH);

  // Escala automática simple
  float minVal = -0.05;
  float maxVal = 0.5;
  
  // Contador de marcas iniciales
  fill(30);
  textAlign(LEFT, TOP);
  textSize(30);
  text("Marcas iniciales: " + marcasIniciales, 10, 10);

  fill(0);
  textSize(12);
  textAlign(RIGHT, CENTER);
 
 // Etiquetas Y
  text(nf(maxVal, 1, 4), plotX - 5, plotY);
  text(nf(minVal, 1, 4), plotX - 5, plotY + plotH);

  // Etiquetas X
  textAlign(CENTER, TOP);
  text("0 s", plotX, plotY + plotH + 5);
  text("5 s", plotX + plotW, plotY + plotH + 5);

  stroke(0, 0, 200);
  noFill();
  beginShape();

  int totalPoints = bufferFull ? maxPoints : bufferIndex;
  if (totalPoints < 2) return;

  int startIndex = bufferFull ? bufferIndex : 0;


  for (int i = 0; i < totalPoints; i++) {
    int idx = (startIndex + i) % maxPoints;
    float x = map(i, 0, maxPoints - 1, plotX, plotX + plotW);
    float y = map(buffer[idx], minVal, maxVal, plotY + plotH, plotY);
    y = constrain(y, plotY, plotY + plotH);  // evitar que salga del marco
    vertex(x, y);
  }

  endShape();
}

void restartSketch() {
  if (output != null) {
    output.flush();
    output.close();
  }
  if (myPort != null) {
    myPort.stop();
  }

  try {
    // Gets the folder where the exe is running from
    String exeDir = System.getProperty("user.dir");
    
    // Find any .exe in that folder
    File dir = new File(exeDir);
    File[] exeFiles = dir.listFiles((d, name) -> name.endsWith(".exe"));
    
    if (exeFiles != null && exeFiles.length > 0) {
      Runtime.getRuntime().exec(exeFiles[0].getAbsolutePath());
      println("Relaunching: " + exeFiles[0].getAbsolutePath());
    } else {
      println("No .exe found in: " + exeDir);
    }
  } catch (Exception e) {
    println("Error al reiniciar: " + e.getMessage());
  }

  exit();
}
