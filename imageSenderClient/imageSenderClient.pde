
import processing.net.*;
import processing.video.*;


// final String serverIP = "192.168.1.4"
final String serverIP = "127.0.0.1";

int state;  // the state of the finite-state machine that controlls the sending of data
Client theClient;
Capture cam;
JPGEncoder jpg;


void setup() {
  state = 0;
  jpg = new JPGEncoder();
  
  cam = new Capture(this, Capture.list()[1]);
  cam.start();
  
  background(0);
}


void draw() {
  manage_clientNetwork();
}


void manage_clientNetwork() {
  switch( state ){
    case 0:  // we have not connected to the server
      // if there were a client, we stop it
      if( theClient != null ) theClient.stop();
      // we connect the client to the host on port 5204
      System.out.println( "Starting client..." );
      theClient = new Client( this , serverIP , 5203 );
      // we wait a little
      try{
        Thread.sleep( 1000 );
      }catch( Exception e ){
        System.out.println( "NetworkDataManager: not able to sleep in the thread." );
      }
      // if we connect
      if( theClient.active() ){
        System.out.println( " started." );
        state = 1;  // we can start sending images
      }else{
        System.out.println( " not able to start the client." );
      }
      break;
    case 1:  // we have connected to the server. We are waiting for an image request
      if( theClient.active() ){  // if the client is still active,
        if( theClient.available() > 0 ){  // and if it has something in its buffer (an image request),
          theClient.clear();  // we clear the buffer
          state = 2;  // and we go to send the image
        }
      }else{  // if the client is not active,
        state = 0;  // we try to reconnect
      }
      break;
    case 2:  // we send the image
      // if there is a new image
      if( cam.available() ){
        // we read it
        cam.read();
        try{
          // we try to encode it
          PImage img = cam.get();
          img.resize( 640 , 0 );
          byte[] jpgBytes = jpg.encode( img , 0.99F );
          // Taken from: https://processing.org/discourse/beta/num_1192330628.html
//          client.write( jpgBytes.length / 256 );  DOES NOT WORK: THE LENGTH IS AN INT (4 BYTES)
//          client.write( jpgBytes.length % 256 );  DOES NOT WORK: THE LENGTH IS AN INT (4 BYTES)
          // if all goes well, we prepare the bytes that represent the length
          int l = jpgBytes.length;
          byte[] lengthBytes = new byte[]{ (byte)( l & 0xFF ) , (byte)( ( l >> 8 ) & 0xFF ) , (byte)( ( l >> 16 ) & 0xFF ) , (byte)( ( l >> 24 ) & 0xFF ) };
          // and if the client is still active
          if( theClient.active() ){
            // then, we write the bytes
            theClient.write( lengthBytes );
            theClient.write( jpgBytes );
            // and we go to wait for a new image request
            state = 1;
          }else{  // if it is not, we go to state 0
            state = 0;
          }
        }catch( Exception e ){
          e.printStackTrace();
        }
      }
      break;
    default:
      state = 0;
      break;
  }
}
