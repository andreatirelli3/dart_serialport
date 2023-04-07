import 'dart:async';
import 'dart:convert';
// import 'dart:html';
import 'package:dcli/dcli.dart';
import 'package:libserialport/libserialport.dart';

// ignore_for_file: avoid_print

class FiscalPrinterEpson {
  int _cnt = 0;
  final String STX = '\x02';
  final String IDEN = 'E';
  final String ETX = '\x03';

  set cnt(int cnt) {
    _cnt = cnt;
  }

  /// Calcola il checksum per un dato comando. Questo valore deve essere
  /// aggiunto in fondo al comando da inviare, ma prima del carattere di termine
  /// sequenza.
  String _getChecksum(String command) {
    // (1) Calcolo il checksum.
    var checksum = 0;
    for (var i = 0; i < command.length; i++) {
      checksum += command.codeUnitAt(i);
    }
    checksum = checksum % 100;
    // (2) Restituisco il checksum, assicurandomi che sia scritto con due cifre.
    if (checksum < 10) return '0$checksum';
    return '$checksum';
  }

  String _formatCNT() {
    String CNT;
    if (_cnt < 10) {
      CNT = '0' + _cnt.toString();
    } else {
      CNT = _cnt.toString();
    }

    return CNT;
  }

  String reset() {
    String CNT = _formatCNT();

    String HEAD1 = '1';
    String HEAD2 = '088';
    String OP = '01';
    String DATA = '';

    String PDU = HEAD1 + HEAD2 + OP + DATA;
    String CKS = _getChecksum(CNT + IDEN + PDU);

    String message_for_printer = STX + CNT + IDEN + PDU + CKS + ETX;
    print("MESSAGE RESET:\t$message_for_printer");

    return message_for_printer;
  }

  String writeDisplay(String line1, String line2) {
    String CNT = _formatCNT();

    String HEAD1 = '1';
    String HEAD2 = '062';
    String OP = '01';
    String DISPLAY = '1';

    String TEXT = line1 + line2;

    String CURS = '00';

    String PDU = HEAD1 + HEAD2 + OP + DISPLAY + TEXT + CURS;
    String CKS = _getChecksum(CNT + IDEN + PDU);

    String message_for_printer = STX + CNT + IDEN + PDU + CKS + ETX;
    print("MESSAGE WRITE_DISPLAY:\t$message_for_printer");

    return message_for_printer;
  }
}

class ComPort {
  final String port;
  final int rate;
  final int timeout;
  static late SerialPort serialPort;
  static late SerialPortReader serialPortReader;
  static int factor = 1;
  static String initString = '';

  /// Init the port
  ComPort({
    required this.port,
    required this.rate,
    required this.timeout,
  }) {
    serialPort = SerialPort(port);
  }

  void communicationEPSON(
      {required FiscalPrinterEpson printer, required String command}) {
    print("Command: $command");
    if (open()) {
      try {
        print("Generating config ...");
        config();

        print("Writing on the serial port ...");
        // writeInPort(_writeDisplay(line1: "aaaaaaaaaaaaaaaaaaa1", line2: "bbbbbbbbbbbbbbbbbbb2"));
        if (command == 'r') {
          writeInPort(printer.reset());
        } else {
          writeInPort(printer.writeDisplay(
              "        DART        ", "      TEST COM      "));
        }

        print("Reading the response from the serial port ...");
        readPort();
      } catch (_) {}
    }
  }

  void communicationCPI(String command) {
    print("Command: $command");
    String terminator = '<CR>';
    if (open()) {
      try {
        print("Generating config ...");
        config();

        print("Writing on the serial port ...");
        writeInPort(command + terminator);

        print("Reading the response from the serial port ...");
        readPort();
      } catch (_) {}
    }
  }

  /// Open the port for Read and Write
  bool open() {
    if (serialPort.isOpen) {
      try {
        serialPort.close();
      } catch (_) {}
    }

    if (!serialPort.isOpen) {
      if (!serialPort.openReadWrite()) {
        return false;
      }
    }

    return true;
  }

  /// Configure the port
  config() {
    /// CPI:
    ///   - stopBits: 1
    ///   - bits: 8
    ///   - parity: 0
    ///
    /// EPSON:
    ///   - stopBits: 1
    ///   - bits: 8
    ///   - parity: 0
    int stopBits = 1;
    int bits = 8;
    int parity = 0;

    /* ... */
    /// CPI:
    ///   - initString: RS<CR>
    ///
    /// EPSON:
    ///   - initString: 24E10850175
    initString = "24E10850175";

    SerialPortConfig config = serialPort.config;
    config.baudRate = rate;
    config.stopBits = stopBits;
    config.bits = bits;
    config.parity = parity;
    serialPort.config = config;
  }

  writeInPort(String value) {
    try {
      print("\tWrite: ${utf8.encoder.convert(value)}");
      int bitsWrote = serialPort.write(utf8.encoder.convert(value));
      print("\tWrote N bit: $bitsWrote");
      print("\tPort signals: ${serialPort.signals}");
    } catch (_) {}
  }

  readPort() {
    try {
      serialPortReader = SerialPortReader(serialPort);
    } catch (_) {}
  }

  Future<String> getRespone() async {
    String decodedResponse = '';

    var completer = Completer<String>();

    try {
      String response = '';
      print("\t\tListener ...");
      serialPortReader.stream.listen((event) async {
        decodedResponse += utf8.decode(event);
        print("\t\tRead: $decodedResponse");

        response = decodedResponse;

        completer.complete(response);
        completer.future;
      });

      await Future.delayed(Duration(milliseconds: timeout), () {
        serialPort.close();
        return response;
      });

      return response;
    } catch (e) {
      print("\t\tError: $e");
      return 'ERROR';
    }
  }
}

void main() async {
  /// CPI:
  ///   - port: COM11
  ///   - rate: 115200
  ///   - timeout: 2000?
  ///
  /// EPSON:
  ///   - port: COM2
  ///   - rate: 57600
  ///   - timeout: 2000?


  /**
  final port = ComPort(port: 'COM3', rate: 115200, timeout: 5000);
  port.communicationCPI("CS");

  await port.getRespone().then((value) {
    print("Returned: $value");
  });
  */

  final printer = FiscalPrinterEpson();

  final port = ComPort(port: 'COM2', rate: 57600, timeout: 5000);

  port.communicationEPSON(printer: printer, command: 'r');

  /// async return
  await port.getRespone().then((value) {
    final endIndex = value.indexOf("E", 0);
    int cnt = int.parse(value.substring(1, endIndex));
    printer.cnt = cnt;
  });

  
  port.communication(printer: printer, command: 'w');

  /// async return
  await port.getRespone().then((value) {
    final endIndex = value.indexOf("E", 0);
    int cnt = int.parse(value.substring(1, endIndex));
    printer.cnt = cnt;
  });
}
