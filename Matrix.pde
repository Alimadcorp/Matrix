import processing.sound.*;
import java.io.*;
import java.awt.Toolkit;
import java.awt.datatransfer.DataFlavor;

boolean ready = false, rainbow = false, showingTitle = false;
float[] raindrops, r2, speeds, s2;
int size = 10;
float t_framerate = 120;
int w, h;
int repeatCount = 0;
int repeatMax = 0;
int lastRepeatTime = 0;
int repeatDelay = 1000;
boolean isRepeating = false;
ArrayList<Float> bars = new ArrayList<>();
ArrayList<Character> barChars = new ArrayList<>();
ArrayList<Character> input = new ArrayList<>();
ArrayList<Character> rep = new ArrayList<>();
ArrayList<String> nextOutputs = new ArrayList<>();
boolean playMode = false;
float charDelay = 3000;
float charRate = 1;
boolean on = true, help = false;
ArrayList<Drop> drops = new ArrayList<>();
int score = 0;
float[] pows;
float minDelay = 200,
  maxSpeed = 1.3;
float gRD = 10,
  gRS = 0.001;
ArrayList<Explosion> explosions = new ArrayList<>();
float vel = 0.1;
float delay = 1000;
float t = 0.0;
float[] introRainDrops;
ArrayList<Integer> charProg = new ArrayList<>();
ArrayList<String> outputs = new ArrayList<>();
int layer = 0;
boolean done1 = false,
  done2 = false,
  done3 = false;
ArrayList<Float> outputProg = new ArrayList<>();
String lastCommand;
String allCharacters =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-=!@#$%^&*()_+[];',./{}:<>?`~";
String playModeCharacters =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-=.,/";
char[] range = allCharacters.toCharArray();
char[] playChars = playModeCharacters.toCharArray();
String lC;
PFont digitalFont;
color bgColor;
float bgOpacity = 20;
float speed = 1;
color textColor;
float cursorBlinkInterval = 500;
float cursorTimer = cursorBlinkInterval;
boolean cursorVisible = true;
int cursorPos = 0;
ArrayList<ShellLine> shellLines = new ArrayList<>();

void preload() {
  digitalFont = createFont("fonts/console.ttf", size);
}

void setup() {
  size(700, 500, P2D);
  fullScreen();
  preload();
  frameRate(120);
  bgColor = color(0, 0, 0);
  textColor = color(0, 255, 0);
  initialize(size);
  loadState();
  noStroke();
  noSmooth();
  fft = new FFT(this, bands);
  //fft.input(music);
  amp = new Amplitude(this);
  //amp.input(music);
  background(0);
  initShell();
  generateHelpFile();
}
SoundFile music;
FFT fft;
Amplitude amp;

int bands = 128;
String currentPath = "test.mp3";
int inf = 0; // invert after frame
int lastBeatTime = 0;
int beatCooldown = 200;

void detectBeat(float level) {
  int now = millis();
  if (level > 0.6 && now - lastBeatTime > beatCooldown) {
    inf = 5;
    color temp = bgColor;
    bgColor = textColor;
    textColor = temp;
    lastBeatTime = now;
  }
}

void handleCommand(String command) {
  if (!command.startsWith("music ")) return;

  String arg = command.substring(6).trim();

  if (arg.equalsIgnoreCase("play")) {
    if (music != null && !music.isPlaying()) music.play();
  } else if (arg.equalsIgnoreCase("stop")) {
    if (music != null && music.isPlaying()) music.pause();
  } else {
    loadMusic(arg);
  }
}

void loadMusic(String path) {
  try {
    if (music != null) music.stop();
    currentPath = path;
    music = new SoundFile(this, currentPath);
    music.play();

    fft.input(music);
    amp.input(music);

    println("Loaded and playing: " + currentPath);
  }
  catch (Exception e) {
    println("Failed to load music: " + e.getMessage());
  }
}

void addToOutput(String line) {
  if (line.contains("\n")) {
    String[] lines = line.split("\n");
    for (int i = lines.length - 1; i > 0; i--) {
      nextOutputs.add(lines[i]);
    }
    return;
  }
  nextOutputs.add(line);
}

float lineTimeout = 8;
int paddingTop = 2;

class ShellLine {
  String text;
  float timeAdded;
  float alpha = 255;

  ShellLine(String text) {
    this.text = text;
    timeAdded = millis();
  }

  void update() {
    if (lineTimeout > 0) {
      float age = (millis() - timeAdded) / 1000.0;
      if (age > lineTimeout) alpha = max(0, alpha - 4);
    }
  }

  boolean isExpired() {
    return alpha <= 0;
  }
}

void addShellLine(String line) {
  shellLines.add(new ShellLine(line));
  addToOutput(line);
}

void drawShellBox() {
  int maxLines = height / size - 1;
  while (shellLines.size() > maxLines) {
    shellLines.remove(0);
  }

  float boxHeight = shellLines.size() * size;
  float boxWidth = textWidth(getLongestLineText());

  fill(bgColor, 200);
  noStroke();
  rect(0, size * (paddingTop - 1), boxWidth, boxHeight);

  textSize(size);
  for (int i = 0; i < shellLines.size(); i++) {
    ShellLine line = shellLines.get(i);
    line.update();
    fill(textColor, line.alpha);
    text(line.text, 0, (i + paddingTop) * size);
  }

  shellLines.removeIf(l -> l.isExpired());
}

String getLongestLineText() {
  String longest = "";
  for (ShellLine l : shellLines) {
    if (l.text.length() > longest.length()) longest = l.text;
  }
  return longest;
}

String execInput = "";
StringBuilder output = new StringBuilder();
BufferedWriter shellWriter;
BufferedReader shellReader;
Thread outputReaderThread;
Process shellProcess;

void initShell() {
  try {
    ProcessBuilder pb = new ProcessBuilder("powershell.exe");
    pb.redirectErrorStream(true);
    shellProcess = pb.start();

    shellWriter = new BufferedWriter(new OutputStreamWriter(shellProcess.getOutputStream()));
    shellReader = new BufferedReader(new InputStreamReader(shellProcess.getInputStream()));

    outputReaderThread = new Thread(() -> {
      try {
        String line;
        while ((line = shellReader.readLine()) != null) {
          shellAppend(line);
        }
      }
      catch (IOException e) {
        shellAppend("Error reading output: " + e.getMessage());
      }
    }
    );
    outputReaderThread.start();

    ready = true;
  }
  catch (IOException e) {
    shellAppend("Failed to start PowerShell: " + e.getMessage());
  }
}

void execute(String command) {
  try {
    if (command.trim().equals("shutdown /h")) {
      on = false;
      background(0);
    }
    shellWriter.write(command + "\n");
    shellWriter.flush();
  }
  catch (IOException e) {
    shellAppend("Write error: " + e.getMessage());
  }
}

void killShellProcess() {
  try {
    shellAppend("^C");
    shellProcess.destroyForcibly();
    outputReaderThread.interrupt();
    initShell();
  }
  catch (Exception e) {
    shellAppend("Error killing shell: " + e.getMessage());
  }
}

void shellAppend(String line) {
  if (!line.trim().equals("")) {
    addShellLine(line);
  }
}

void initialize(int newSize) {
  size = newSize;
  textSize(size);
  textFont(digitalFont);
  updateWindowSize();
  updateArrays();
}

void updateWindowSize() {
  w = floor(width / size);
  h = floor(height / size);
}

void updateArrays() {
  raindrops = new float[w];
  r2 = new float[w];
  speeds = new float[w];
  s2 =new float[w];
  introRainDrops = new float[w];
  pows = new float[w];
  for (int i = 0; i < w; i++) {
    raindrops[i] = random(0, -h - 1);
    r2[i] = random(0, -h - 1);
    speeds[i] = random(0.5, 1);
    s2[i] = random(0.5, 1);
    introRainDrops[i] = 0;
    pows[i] = 255;
  }
}

void draw() {
  if (on) {
    if (inf > 0) {
      inf--;
      if (inf == 1) {
        color temp = bgColor;
        bgColor = textColor;
        textColor = temp;
        inf = 0;
      }
    }
    t += 1 / frameRate * 1000;
    textSize(size);
    fill(bgColor, bgOpacity);
    rect(-4, -4, width + 4, height + 4);
    if (!nextOutputs.isEmpty()) {
      outputs.add(nextOutputs.remove(0));
      outputProg.add(0.0);
    }
    if (layer == 0) {
      layer = 2;
    } else if (layer == 2) {
      if (!showingTitle) {
        if (!playMode) {
          drawTypedCharacters();
          drawCursor();
        }
        if (rainbow) {
          drawRainbowCharacters();
        } else {
          drawFallingCharacters();
        }
        drawCommandOutputs();
        drawShellBox();
      } else {
        if (showingTitle) {
          drawTitleScreen();
          return;
        }
      }
    }
    if (isRepeating && millis() - lastRepeatTime >= repeatDelay) {
      if (repeatCount < repeatMax) {
        processCommand(rep, false);
        repeatCount++;
        lastRepeatTime = millis();
      } else {
        isRepeating = false;
      }
    }
    if (help) {
      showHelpScreen();
    }
  }
}

String fullTitle = "";
String[] titleLines;
int titleIndex = 0;
int titleStartTime;
int titleCharDelay = 60;
int titleEndDelay = 2000;

void drawTitleScreen() {
  background(0);
  fill(0, 255, 0);
  textAlign(CENTER, CENTER);

  int elapsed = millis() - titleStartTime;
  int totalChars = elapsed / titleCharDelay;
  int shown = 0;
  float y = height / 2 - (titleLines.length * 20);

  for (int i = 0; i < titleLines.length; i++) {
    String line = titleLines[i];
    textSize(i == 0 ? size * 2 : size);
    int count = min(line.length(), totalChars - shown);
    String shownText = line.substring(0, max(0, count));
    text(shownText, width / 2, y);
    if (count < line.length() && (millis() / 500) % 2 == 0) {
      text("_", width / 2 + textWidth(shownText) / 2 + 5, y);
    }
    y += 40;
    shown += line.length();
  }

  if (totalChars >= fullTitle.replace("\n", "").length() + 1 &&
    elapsed > fullTitle.replace("\n", "").length() * titleCharDelay + titleEndDelay) {
    showingTitle = false;
    removeScreen();
    shellLines.clear();
    outputs.clear();
    nextOutputs.clear();
    outputProg.clear();
    textAlign(LEFT, TOP);
  }
}

void startTitle(String s) {
  fullTitle = s.replace("\\n", "\n");
  titleLines = fullTitle.split("\n");
  titleIndex = 0;
  titleStartTime = millis();
  showingTitle = true;
}

String[] helpLines;

void showHelpScreen() {
  if (helpLines == null) {
    helpLines = loadStrings("help.txt");
  }

  background(0);
  fill(0, 255, 0);
  textAlign(LEFT, TOP);

  float boxWidth = width * 0.9;
  float x = (width - boxWidth) / 2;
  float lineHeight = 20;
  float y = (height - helpLines.length * lineHeight) / 2;

  for (String line : helpLines) {
    text(line, x, y);
    y += lineHeight;
  }
}

void drawTypedCharacters() {
  fill(textColor, 100);
  for (int i = 0; i < charProg.size(); i++) {
    for (int j = 0; j < constrain(charProg.get(i), 0, h + 1); j++) {
      text(input.get(i), i * size, j * size);
    }
    if (charProg.get(i) <= 2 + h) {
      for (int j = i; j < w; j++) {
        text(input.get(i), j * size, charProg.get(i) * size);
      }
    }
    charProg.set(i, charProg.get(i) + 1);
  }
}

void drawCursor() {
  if (millis() - cursorTimer >= cursorBlinkInterval) {
    cursorVisible = !cursorVisible;
    cursorTimer = millis();
  }
  if (cursorVisible && cursorPos >= 0 && cursorPos <= input.size()) {
    fill(textColor);
    rect(cursorPos * size, size, size, size / 5);
  }
}

void drawFallingCharacters() {
  float level = (amp != null) ? amp.analyze() : 0;
  if (amp != null) detectBeat(level);
  if (fft != null) fft.analyze();
  if (fft != null) {
    float maxVal = 0;
    for (int i = 0; i < fft.spectrum.length; i++) {
      maxVal = max(maxVal, fft.spectrum[i]);
    }
    for (int i = 0; i < fft.spectrum.length; i++) {
      fft.spectrum[i] = lerp(fft.spectrum[i], fft.spectrum[i] / max(0.001, maxVal), 0.5);
    }
  }

  for (int j = 0; j < bars.size(); j++) {
    bars.set(j, bars.get(j) + speed);
    if (bars.get(j) > h + 2) {
      bars.remove(j);
      barChars.remove(j);
    }
  }

  for (int i = 0; i < w; i++) {
    if (input.size() <= i) {
      float energy = 0;
      raindrops[i] += speeds[i] * speed;
      r2[i] += s2[i] * speed;

      if (raindrops[i] > h + 2) raindrops[i] = playMode ? -10000000 : 0;
      if (r2[i] > h + 2) r2[i] = playMode ? -10000000 : 0;

      if (fft != null && music != null && music.isPlaying()) {
        int bandIndex = int(map(i, 0, w, 0, fft.spectrum.length - 50));
        energy = fft.spectrum[bandIndex];
        float mapped = constrain(energy * height, 0, height) / 14;
        raindrops[i] = h - mapped;
        r2[i] = lerp(r2[i], h - mapped, 0.5);
      }

      for (int j = 0; j < bars.size(); j++) {
        fill(textColor);
        text(barChars.get(j), i * size, (bars.get(j) + int(raindrops[i] / 20)) * size);
      }

      char t1 = range[int(random(0, range.length))];
      char t2 = range[int(random(0, range.length))];
      float x = i * size;
      float mirrorX = width - x - size;
      float y1 = int(raindrops[i]) * size;
      float y2 = int(r2[i]) * size;
      float tw = max(textWidth(t1), textWidth(t2));
      float th = textAscent() + textDescent();
      float top = min(y1, y2);
      float bottom = max(y1, y2);

      if (music != null && music.isPlaying()) {
        fill(bgColor, 255);
        noStroke();
        rect(x, top, tw, (bottom - top) + th);
        fill(textColor);
        text(t1, x, y1);
        text(t2, x, y2);
        int steps = int(abs(y2 - y1) / (th * 1.2));
        for (int j = 1; j < steps; j++) {
          float y = lerp(y1, y2, j / float(steps));
          char midText = range[int(random(0, range.length))];
          text(midText, x, y);
        }
        fill(bgColor, 255);
        rect(mirrorX, top, tw, (bottom - top) + th);
        fill(textColor, 255);
        text(t1, mirrorX, y1);
        text(t2, mirrorX, y2);

        for (int j = 1; j < steps; j++) {
          float y = lerp(y1, y2, j / float(steps));
          char midText = range[int(random(0, range.length))];
          text(midText, mirrorX, y);
        }
      } else {
        fill(textColor);
        text(t1, x, y1);
        text(t2, x, y2);
      }
    }
  }
}

float[] scale(float[] base, int target) {
  float[] result = new float[target];
  float factor = (float)(base.length - 1) / (target - 1);
  for (int i = 0; i < target; i++) {
    float index = i * factor;
    int low = floor(index);
    int high = min(low + 1, base.length - 1);
    float t = index - low;
    result[i] = lerp(base[low], base[high], t);
  }
  return result;
}

void drawRainbowCharacters() {
  colorMode(HSB);
  for (int j = 0; j < bars.size(); j++) {
    bars.set(j, bars.get(j) + speed);
    if (bars.get(j) > h + 2) {
      bars.remove(j);
      barChars.remove(j);
    }
  }

  for (int i = 0; i < w; i++) {
    if (input.size() <= i) {
      raindrops[i] += speeds[i] * speed;
      r2[i] += s2[i] * speed;

      if (raindrops[i] > h + 2) {
        raindrops[i] = playMode ? -10000000 : 0;
      }
      if (r2[i] > h + 2) {
        r2[i] = playMode ? -10000000 : 0;
      }

      for (int j = 0; j < bars.size(); j++) {
        float hue = (frameCount + i * 10 + j * 5) % 256;
        fill(hue, 255, 255);
        text(barChars.get(j), i * size, (bars.get(j) + int(raindrops[i] / 20)) * size);
      }

      float hue1 = (frameCount + i * 7) % 256;
      float hue2 = (frameCount + i * 7 + 100) % 256;

      fill(hue1, 255, 255);
      text(range[int(random(0, range.length))], i * size, int(raindrops[i]) * size);

      fill(hue2, 255, 255);
      text(range[int(random(0, range.length))], i * size, int(r2[i]) * size);
    }
  }
  colorMode(RGB);
}

void drawCommandOutputs() {
  textSize(size);
  for (int i = 0; i < outputProg.size(); i++) {
    if (outputProg.get(i) < h + 3) {
      outputProg.set(i, outputProg.get(i) + 1);
      int xPos = width / 2 - (outputs.get(i).length() * size) / 2;
      int yPos = int(outputProg.get(i)) * size;
      fill(bgColor, 200);
      rect(xPos, yPos - size, size * outputs.get(i).length(), size);
      fill(textColor);
      text(outputs.get(i), xPos, int(yPos));
    }
    if (outputs.get(i) == "Exiting Application." && outputProg.get(i) > h) {
      exit();
    }
  }
}

boolean CTRL = false;

void keyReleased() {
  if (keyCode == CONTROL) {
    CTRL = false;
  }
}

void mousePressed() {
  if (!on) {
    on = true;
    startTitle(fullTitle);
  }
}

void keyPressed() {
  if (!on) {
    on = true;
    startTitle(fullTitle);
  }
  if ((keyCode == 'c' || keyCode == 'C') && CTRL) {
    killShellProcess();
    addToOutput("Stopped");
  }
  if ((keyCode == 'v' || keyCode == 'V') && CTRL) {
    try {
      String pasted = (String) Toolkit.getDefaultToolkit()
        .getSystemClipboard().getData(DataFlavor.stringFlavor);
      char[] p = pasted.toCharArray();
      for (int i = 0; i < p.length; i++) {
        input.add(cursorPos, p[i]);
        charProg.add(cursorPos, 0);
        cursorPos++;
      }
    }
    catch (Exception e) {
    }
  }
  if (keyCode == CONTROL) {
    CTRL = true;
  } else if (keyCode == BACKSPACE) {
    if (input.size() > 0 && cursorPos > 0) {
      input.remove(cursorPos - 1);
      charProg.remove(cursorPos - 1);
      cursorPos--;
    }
  } else if (keyCode == DELETE) {
    if (cursorPos < input.size()) {
      input.remove(cursorPos);
      charProg.remove(cursorPos);
    }
  } else if (keyCode == LEFT) {
    if (cursorPos > 0) {
      cursorPos--;
    }
  } else if (keyCode == RIGHT) {
    if (cursorPos < input.size()) {
      cursorPos++;
    }
  } else if (keyCode == UP) {
    if (lastCommand != null) {
      ArrayList<Character> list = new ArrayList<>();
      ArrayList<Integer> progs = new ArrayList<>();
      char[] arr = lastCommand.toCharArray();
      for (int i = 0; i < arr.length; i++) {
        list.add(arr[i]);
        progs.add(0);
      }
      input = list;
      charProg = progs;
      cursorPos = arr.length;
    }
  } else if (keyCode != ENTER && keyCode != SHIFT && keyCode != CONTROL && keyCode != ALT) {
    if (isAlphanumericOrSymbol(key)) {
      lC = str(key);
      input.add(cursorPos, key);
      charProg.add(cursorPos, 0);
      cursorPos++;
    }
  } else if (keyCode == ENTER) {
    if (showingTitle) {
      showingTitle = false;
      removeScreen();
      shellLines.clear();
      outputs.clear();
      nextOutputs.clear();
      outputProg.clear();
      textAlign(LEFT, TOP);
    }
    if (help) help = false;
    processCommand(input, true);
  }
}

void generateHelpFile() {
  String[][] table = {
    { "COMMAND", "Any command except listed below runs in powershell" },
    { "size N", "Set font size" },
    { "fps N", "Set da frame rate" },
    { "speed N", "Set animation speed" },
    { "setarr CHARS", "Set character array" },
    { "reset", "Reset character array" },
    { "music PATH", "Play the music file at PATH along with visuals" },
    { "cls OR clear", "Clear screen" },
    { "title TITLE", "Define starting title" },
    { "color R,G,B", "Set text color" },
    { "color NAME", "Set text color :D" },
    { "bg R,G,B", "Set background color" },
    { "bg NAME", "Set background color D:" },
    { "fade N", "Set fade amount" },
    { "invert", "Swap background and text colors" },
    { "flush", "Reset app settings" },
    { "font NAME", "Set font" },
    { "font ls", "List available fonts!!" },
    { "echo $\"TEXT\"", "Print TEXT" },
    { "cat FILE", "Display contents of FILE" },
    { "save", "Save state" },
    { "load", "Load state" },
    { "repeat N D", "Repeat last command N times with D ms delay" },
    { "stop", "Stop repeating funtion" },
    { "help", "Show this screen" },
    { "history", "Show last command" },
    { "date", "Show current date" },
    { "time", "Show current time" },
    { "rainbow", "Switch rainbow mode" },
    { "version", "Show version" },
    { "exec COMMAND", "Run COMMAND in powershell" },
    { "timout T", "Set timeout of lines in the shell output" },
    { "COMMAND > FILE.txt", "Save COMMAND output to FILE" },
    { "COMMAND >> FILE.txt", "Append COMMAND output to FILE" },
    { "exit", "Quit app" }
  };

  String[] lines = new String[table.length + 3];
  lines[0] = "+----------------------+----------------------------------------------------+";
  lines[1] = "| Command              | Description                                        |";
  lines[2] = "+----------------------+----------------------------------------------------+";

  for (int i = 0; i < table.length; i++) {
    String cmd = String.format("| %-20s | %-50s |", table[i][0], table[i][1]);
    lines[i + 3] = cmd;
  }

  lines = append(lines, "+----------------------+----------------------------------------------------+");
  lines = append(lines, "Press enter to exit this screen");

  saveStrings("help.txt", lines);
}

void processCommand(ArrayList<Character> custom, boolean clear) {
  String inp = "";
  for (int i = 0; i < custom.size(); i++) {
    inp += custom.get(i);
  }
  if (!inp.isEmpty()) {
    String[] commandAndParam = parseInput(inp);
    String command = commandAndParam[0];
    String parameter = commandAndParam[1];
    String output = "";
    String redirFile = null;
    boolean append = false;

    if ((parameter.contains(">>") || parameter.contains(">")) && !command.equals("exec")) {
      String[] parts;
      if (parameter.contains(">>")) {
        parts = parameter.split(">>", 2);
        append = true;
      } else {
        parts = parameter.split(">", 2);
      }
      parameter = parts[0].trim();
      redirFile = parts[1].trim();
    }

    switch (command) {
    case "exit":
      output = "Exiting Application.";
      break;
    case "music":
      handleCommand("music " + parameter);
      output = "Playing " + parameter;
      break;
    case "size":
      try {
        int newSize = int(parameter.trim());
        if (newSize > 0) {
          initialize(newSize);
          output = "Font size and arrays re-initialized to: " + newSize;
        } else {
          output = "Size must be greater than 0.";
        }
      }
      catch (NumberFormatException e) {
        output = "Invalid size format. Please enter a valid number.";
      }
      break;
    case "fps":
      try {
        float fps = float(parameter.trim());
        if (fps > 0) {
          frameRate(fps);
          output = "Framerate set to: " + fps;
          t_framerate = fps;
        } else {
          output = "Framerate must be greater than 0.";
        }
      }
      catch (NumberFormatException e) {
        output = "Invalid fps format. Please enter a valid number.";
      }
      break;
    case "speed":
      try {
        float spd = float(parameter.trim());
        speed = spd;
        output = "Speed set to: " + spd;
      }
      catch (NumberFormatException e) {
        output = "Invalid speed format. Please enter a valid number.";
      }
      break;
    case "setarr":
      if (parameter != "") {
        range = parameter.toCharArray();
        output = "Character array changed to: " + parameter;
      } else {
        output = "No parameter provided for " + command + ".";
      }
      break;
    case "reset":
      range = allCharacters.toCharArray();
      playChars = playModeCharacters.toCharArray();
      output = "Character array reset.";
      break;
    case "cls":
      removeScreen();
      shellLines.clear();
      outputs.clear();
      nextOutputs.clear();
      outputProg.clear();
      output = "";
      break;
    case "color":
      output = setColor(parameter);
      break;
    case "bg":
      output = setBackgroundColor(parameter);
      break;
    case "fade":
      output = setFade(parameter);
      break;
    case "invert":
      int temp = textColor;
      textColor = bgColor;
      bgColor = temp;
      output = "";
      break;
    case "flush":
      File f = new File(dataPath("state.txt"));
      if (f.exists()) f.delete();
      output = "DELETE";
      break;
    case "font":
      if (!parameter.equals("ls")) {
        setFont(parameter);
        output = "Font set to: " + parameter;
      } else {
        String[] fontFiles = listFontFiles();
        if (fontFiles.length == 0) {
          output = "No fonts found in fonts/";
        } else {
          output = "Available fonts: ";
          for (String ff : fontFiles) {
            output += ff.replaceAll("\\.[^.]+$", "") + ",";
          }
        }
      }
      break;
    case "version":
      output = "Madrix CLI 2.2";
      break;
    case "echo":
      output = parameter;
      break;
    case "cat":
      String filename = parameter.trim();
      String[] lines = loadStrings(filename);
      if (lines == null) {
        output = "File not found: " + filename;
      } else {
        output = join(lines, "\n");
      }
      break;
    case "help":
      help = true;
      break;
    case "time":
      output = "Time: " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
      break;
    case "title":
      startTitle(parameter);
      output = "";
      break;
    case "date":
      output = "Date: " + year() + "-" + nf(month(), 2) + "-" + nf(day(), 2);
      break;
    case "clear":
      removeScreen();
      shellLines.clear();
      outputs.clear();
      nextOutputs.clear();
      outputProg.clear();
      output = "";
      break;
    case "history":
      output = "Last command: " + lastCommand;
      break;
    case "save":
      saveState();
      output = "State saved.";
      break;
    case "load":
      loadState();
      output = "State loaded.";
      break;
    case "repeat":
      if (lastCommand.trim().startsWith("repeat")) {
        output = "Cannot repeat a repeat.";
        break;
      }

      String[] parts = parameter.trim().split("\\s+");
      int times = 1;
      int delay = 1000;

      if (parts.length > 0 && !parts[0].isEmpty()) {
        try {
          times = max(1, int(parts[0]));
        }
        catch (NumberFormatException e) {
          output = "Invalid number. Defaulting to 1.";
        }
      }

      if (parts.length > 1) {
        try {
          delay = max(0, int(parts[1]));
        }
        catch (NumberFormatException e) {
          output = "Invalid delay. Defaulting to 1000ms.";
        }
      }

      repeatCount = 0;
      repeatMax = times;
      repeatDelay = delay;
      lastRepeatTime = millis();
      isRepeating = true;
      char[] rept = lastCommand.toCharArray();
      rep.clear();
      for (int i = 0; i < rept.length; i++) {
        rep.add(rept[i]);
      }
      output = "Repeating " + times + " times with " + delay + "ms delay.";
      break;
    case "stop":
      if (isRepeating) {
        isRepeating = false;
        output = "Stopped";
      } else {
        output = "Nothing to stop, duh.";
      }
      break;
    case "timeout":
      try {
        lineTimeout = float(parameter);
      }
      catch(NumberFormatException e) {
      }
      break;
    case "rainbow":
      rainbow = !rainbow;
      output = "";
      break;
    case "exec":
      execute(parameter);
      break;
    default:
      execute(command + " " + parameter);
      break;
    }
    if (input.size() > 0 && !command.equals("repeat")) {
      lastCommand = inp;
    }
    if (redirFile != null) {
      File file = new File(redirFile);
      try {
        if (append && file.exists()) {
          String[] old = loadStrings(file);
          String[] combined = append(old, output);
          saveStrings(file, combined);
        } else {
          saveStrings(file, new String[]{output});
        }
        output = "Written to " + redirFile;
      }
      catch (Exception e) {
        output = "Error writing to " + redirFile;
      }
    }


    addToOutput(output);

    // Reset state
    if (clear) {
      barChars.clear();
      bars.clear();
      input.clear();
      charProg.clear();
      cursorPos = 0;
    }
    if (output == "DELETE") {
      lastCommand = "";
      initialize(10);
      t_framerate = 120;
      frameRate(t_framerate);
      speed = 1;
      range = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-=!@#$%^&*()_+[];',./{}:<>?`~".toCharArray();
      textColor = color(0, 255, 0);
      bgColor = color(0, 0, 0);
      saveState();
    } else {
      saveState();
    }
  }
}

String[] listFontFiles() {
  File fontDir = new File(sketchPath("fonts"));
  if (!fontDir.exists() || !fontDir.isDirectory()) return new String[0];

  return fontDir.list((dir, name) -> name.toLowerCase().endsWith(".ttf") || name.toLowerCase().endsWith(".otf") || name.toLowerCase().endsWith(".vlw"));
}

void saveState() {
  String r = "";
  for (int i = 0; i < range.length; i++) {
    r += range[i];
  }
  String[] save = { lastCommand, str(size), str(t_framerate), str(speed), r, str(textColor), str(bgColor), str(lineTimeout), fullTitle.replace("\n", "\\n") };
  saveStrings("state.txt", save);
}

void loadState() {
  String[] save = loadStrings("state.txt");
  if (save == null || save.length < 8) return;
  lastCommand = save[0];
  int s = int(save[1]);
  if (s > 0) initialize(s);

  t_framerate = float(save[2]);
  frameRate(t_framerate);

  speed = float(save[3]);
  range = save[4].toCharArray();
  textColor = int(save[5]);
  bgColor = int(save[6]);
  lineTimeout = float(save[7]);
  fullTitle = save[8];
  if (!fullTitle.equals("")) {
    startTitle(fullTitle);
  }
}

void removeScreen() {
  for (int i = 0; i < r2.length; i++) {
    r2[i] = -50;
    raindrops[i] = -80;
  }
}

public String[] gColor(String param) {
  switch (param.toLowerCase()) {
  case "red":
    return new String[]{"255", "0", "0"};
  case "green":
    return new String[]{"0", "255", "0"};
  case "blue":
    return new String[]{"0", "0", "255"};
  case "yellow":
    return new String[]{"255", "255", "0"};
  case "cyan":
    return new String[]{"0", "255", "255"};
  case "magenta":
    return new String[]{"255", "0", "255"};
  case "white":
    return new String[]{"255", "255", "255"};
  case "black":
    return new String[]{"0", "0", "0"};
  case "orange":
    return new String[]{"255", "165", "0"};
  case "purple":
    return new String[]{"128", "0", "128"};
  case "pink":
    return new String[]{"255", "192", "203"};
  case "brown":
    return new String[]{"165", "42", "42"};
  case "gray":
    return new String[]{"128", "128", "128"};
  case "gold":
    return new String[]{"255", "215", "0"};
  case "silver":
    return new String[]{"192", "192", "192"};
  case "lime":
    return new String[]{"0", "255", "0"};
  case "teal":
    return new String[]{"0", "128", "128"};
  case "maroon":
    return new String[]{"128", "0", "0"};
  case "navy":
    return new String[]{"0", "0", "128"};
  case "olive":
    return new String[]{"128", "128", "0"};
  case "violet":
    return new String[]{"238", "130", "238"};
  default:
    return param.split(",");
  }
}

String setColor(String parameter) {
  String[] rgb;
  rgb = gColor(parameter);
  if (rgb.length == 3) {
    try {
      int r = parseInt(rgb[0].trim());
      int g = parseInt(rgb[1].trim());
      int b = parseInt(rgb[2].trim());
      textColor = color(r, g, b);
      return "Text color changed to: (" + r + ", " + g + ", " + b + ")";
    }
    catch (NumberFormatException e) {
      return "Invalid color format. Use 'setcolor R, G, B'.";
    }
  } else {
    return "Invalid color format. Use 'setcolor R, G, B'.";
  }
}

String setBackgroundColor(String parameter) {
  String[] bgRgb = gColor(parameter);
  if (bgRgb.length == 3) {
    try {
      int bgR = parseInt(bgRgb[0].trim());
      int bgG = parseInt(bgRgb[1].trim());
      int bgB = parseInt(bgRgb[2].trim());
      bgColor = color(bgR, bgG, bgB);
      return (
        "Background color changed to: (" + bgR + ", " + bgG + ", " + bgB + ")"
        );
    }
    catch (NumberFormatException e) {
      return "Invalid color format. Use 'setbgcolor R, G, B'.";
    }
  } else {
    return "Invalid color format. Use 'setbgcolor R, G, B'.";
  }
}

String setFade(String parameter) {
  try {
    int opacity = parseInt(parameter.trim());
    if (opacity >= 0 && opacity <= 255) {
      bgOpacity = opacity;
      return "Background opacity changed to: " + opacity;
    } else {
      return "Opacity value must be between 0 and 255.";
    }
  }
  catch (NumberFormatException e) {
    return "Invalid opacity value. Use 'setfade opacity'.";
  }
}
void setFont(String fontName) {
  String fontPath = "fonts/" + fontName.replace(".ttf", "") + ".ttf"; // Adjust extension as needed

  try {
    // Try to load the font
    digitalFont = createFont(fontPath, 72);
    textSize(size);
    textFont(digitalFont);
    addToOutput("Font changed to: " + fontName);
  }
  catch (NumberFormatException e) {
    // Handle the case where the font is not found
    addToOutput("Font not found: " + fontName);
  }

  outputProg.add(0.0);
}

String[] parseInput(String input) {
  input = input.trim();
  String[] parts = splitTokens(input, " ");
  String[] out = new String[2];
  if (parts.length >= 2) {
    String command = parts[0].toLowerCase();
    String parameter = join(subset(parts, 1), " ");
    out[0] = command;
    out[1] = parameter;
  } else if (parts.length == 1) {
    String command = parts[0];
    out[0] = command;
    out[1] = "";
  } else {
    out[0] = "";
    out[1] = "";
  }
  return out;
}

boolean isAlphanumericOrSymbol(char key) {
  if (
    (key >= 'A' && key <= 'Z') ||
    (key >= 'a' && key <= 'z') ||
    (key >= '0' && key <= '9') ||
    "~!@#$%^&*()-=_+[]\\{}|;':\",./<>? ".indexOf(key) != -1
    ) {
    return true;
  }
  return false;
}
class Drop {
  float x, y, speed;
  String ch;
  Drop(float _x, float _y, String _ch, float _speed) {
    this.x = _x;
    this.y = _y;
    this.ch = _ch;
    this.speed = _speed;
  }

  void update() {
    this.y += this.speed;
  }

  void display() {
    fill(textColor);
    text(this.ch, int(this.x) * size, int(this.y) * size);

    if (this.y >= h) {
      if (pows[int(this.x)] <= 0) {
      } else {
        explosions.add(
          new Explosion(
          this.x * size,
          this.y * size,
          size / 1.2,
          20,
          color(255, 0, 0)
          )
          );
        for (var i = 0; i < w; i++) {
          pows[i] -= (255 / abs(this.x - i + 0.001)) * 2;
        }
        this.destroy();
      }
      if (this.y > h + 5) {
        lose();
      }
    }
  }
  void destroy() {
    int index = drops.indexOf(this);
    if (index > -1) {
      drops.remove(index);
    }
  }
}
void lose() {
  playMode = false;
  for (int i = 0; i < raindrops.length; i++) {
    raindrops[i] = 0;
    r2[i] = 0;
  }
  explosions.clear();
  drops.clear();
  delay = 1000;
  vel = 0.1;
}
class Explosion {
  float x, y, radius, t;
  color fillcolor;
  ArrayList<PVector> ptcles;
  Explosion(float _x, float  _y, float  _radius, float _particles, color _color) {
    this.x = _x;
    this.y = _y;
    this.radius = _radius;
    this.t = 1;
    ptcles = new ArrayList<>();
    this.fillcolor = _color;
    for (int i = 0; i < _particles; i++) {
      this.ptcles.add(new PVector(_x, _y));
    }
  }

  void update() {
    this.t += 1 / frameRate * 1000;
    for (int i = 0; i < this.ptcles.size(); i++) {
      float rt = this.t / 1000;
      float speed = 1 / rt;
      speed /= 10;
      //float rad = (i / this.ptcles.size()) * PI * 2;
      float angle = random(TWO_PI);
      PVector force = PVector.fromAngle(angle).mult(random(1, 5) * speed);
      this.ptcles.get(i).add(force);
    }
  }

  void display() {
    if (this.fillcolor == textColor) {
      score += int(this.radius);
    }
    fill(this.fillcolor);
    for (int i = 0; i < this.ptcles.size(); i++) {
      textSize(this.radius * random(0.8, 1.2));
      float xpos = int((this.ptcles.get(i).x - this.radius / 2) / size) * size;
      float ypos = int((this.ptcles.get(i).y - this.radius / 2) / size) * size;
      text(
        str(range[int(constrain(int(xpos + ypos) % range.length, 0, range.length))]),
        xpos,
        ypos
        );
    }
    if (this.t > 1000) {
      this.finito();
    }
  }

  void finito() {
    int index = explosions.indexOf(this);
    if (index > -1) {
      explosions.remove(index);
    }
  }
}
