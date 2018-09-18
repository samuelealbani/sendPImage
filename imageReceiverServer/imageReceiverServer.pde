
import processing.net.*;


final int TIMEOUT_MILLIS = 1 * 3000;  // 3 seconds to wait for the image to arrive after a length reception

int state;  // the state of the finite-state machine that controlls the data reception
int imageLength;  // the length of the byte array that contains the image information
Server theServer;
JPGEncoder jpg;
PImage img;


void setup() {
  size(640, 640);
  
  state = 0;
  jpg = new JPGEncoder();
  
  background(0);
  img = createImage( 0 , 0 , RGB );
}


void draw() {
  manage_serverNetwork();
  image( img , 0 , 0 );
}


void serverEvent() {
  // if there is something new, we manage it
  manage_serverNetwork();
}


void manage_serverNetwork() {
  Client nextClient;
  switch( state ){
    case 0:  // the server is not created
      // we start a server at port 5204
      System.out.println( "Starting server..." );
      theServer = new Server(this, 5203);
      state = 1;  // now the server has been created
      break;
    case 1:  // the server is created. We send an image request
      theServer.write( 0 );  // we send the image request
      if( ( nextClient = theServer.available() ) != null ){  // if there is some client,
        state = 2;  // we go to recieve the length
      }
      break;
    case 2:  // we are waiting for the length to arrive
      // we take the next client if it is available; otherwise we will obtain a null pointer
      if( ( nextClient = theServer.available() ) != null ){  // if there is some client
        if( nextClient.available() >= 4 ){  // and it has sent at least 4 bytes to build the length
          // first, we send another image request so that the client has the next image prepared
          theServer.write( 0 );
          // Taken from: https://processing.org/discourse/beta/num_1192330628.html
//          int imageByteLength = nextClient.read()*256 + nextClient.read();  DOES NOT WORK: THE LENGTH IS AN INT (4 BYTES)
          // we get the four bytes that form the int that represents the length
          byte[] lengthBytes = nextClient.readBytes( 4 );
          // and we compose them into the int
          imageLength = ( ( (lengthBytes[3] & 0xFF) << 24 ) | ( (lengthBytes[2] & 0xFF) << 16 ) | ( (lengthBytes[1] & 0xFF) << 8 ) | (lengthBytes[0] & 0xFF) );
          // now we can try to get the image
          state = 3;
        }
      }else{  // if there is no client,
        state = 1;  // we go to send image requests
      }
      break;
    case 3:  // we are receiving the image
      if( ( nextClient = theServer.available() ) != null ){  // if there is something to receive
        if( nextClient.available() >= imageLength ){  // and we have the full content
          // now we can get the PImage from the bytes
          try{
            // we create the array of bytes to store it
            byte[] jpgBytes = new byte[imageLength];
            // we store it
            nextClient.readBytes( jpgBytes );
            // and we get the image from the bytes
            img = jpg.decode( jpgBytes );
          }catch( Exception e ){
            e.printStackTrace();
          }finally{
            // and no matter what happens, we go to state 2 (receive a new image length)
            state = 2;
          }
        }
      }
      // we also take care if the image takes
      break;
    default:
      state = 0;
      break;
  }
}
