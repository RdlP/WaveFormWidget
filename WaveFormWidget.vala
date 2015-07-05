using Gtk;

namespace Wave {

    public class WaveFormWidget : DrawingArea {

        private bool dragging;
        private bool pressed;
        private double x_mouse;
        private double y_mouse;
        private double x_dragging_mouse;
        private double y_dragging_mouse;
        private string path_wav_file;
        private int16[] data_wav;
        private int max_data;

        public WaveFormWidget () {
            add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK);
            max_data = 0;
        }

        public void set_wav_file(string path){
            path_wav_file = path;
            read_wav_file(path);
        }

        public override bool draw (Cairo.Context cr) {
            var x_rectangle = 1;
            var y_rectangle = 1;

            var rectangle_width = get_allocated_width() - x_rectangle-1;
            var rectangle_height = 180 - y_rectangle - 1;

            Cairo.ImageSurface surface1 = new Cairo.ImageSurface (Cairo.Format.ARGB32, rectangle_width, rectangle_height);
            Cairo.Context context1 = new Cairo.Context (surface1);
            
            context1.set_source_rgb(0, 0, 0);
            context1.set_line_width(2);
            context1.rectangle(x_rectangle, y_rectangle, rectangle_width, rectangle_height);
            context1.fill();

            context1.set_source_rgb(0,1,0);
            context1.move_to(x_rectangle,rectangle_height/2);
            context1.line_to(x_rectangle + rectangle_width, rectangle_height/2);
            context1.stroke();

            cr.set_source_surface(context1.get_target(),0,0);
            cr.paint();

            if (data_wav != null){
                Cairo.ImageSurface plot = new Cairo.ImageSurface (Cairo.Format.ARGB32, rectangle_width, rectangle_height);
                Cairo.Context plot_ctx = new Cairo.Context (plot);
                int step = data_wav.length / rectangle_width;
                double normalized;
                int zero = rectangle_height /2;
                plot_ctx.move_to(0,zero);
                plot_ctx.set_source_rgb(0,1,0);
                for (int i = 0, pixel = 0; i < data_wav.length; i+=step, pixel++){                    
                    normalized = (double)((double)data_wav[i] / (double)max_data) * rectangle_height/2;
                    plot_ctx.line_to(pixel,zero + normalized);
                }
                plot_ctx.stroke();
                cr.set_source_surface(plot_ctx.get_target(),0,0);
                cr.paint();
            }

            Cairo.ImageSurface surface2 = new Cairo.ImageSurface (Cairo.Format.ARGB32, rectangle_width, rectangle_height);
            Cairo.Context context2 = new Cairo.Context (surface2);

            if (pressed){
                context2.set_source_rgb(1,1,1);
                context2.move_to(x_mouse,0);
                context2.line_to(x_mouse,rectangle_height);
                context2.stroke();
            }

            if (dragging){
                context2.set_source_rgb(1, 1, 1);
                context2.set_line_width(1);
                context2.rectangle(x_mouse, y_rectangle, x_dragging_mouse-x_mouse, rectangle_height);
                context2.fill();
            }

            if (pressed || dragging){
                cr.set_operator(Cairo.Operator.DIFFERENCE);
                cr.set_source_surface(context2.get_target(),0,0);
                cr.paint();//_with_alpha(0.8);
            }

            return false;
        }

        public override bool button_press_event (Gdk.EventButton event) {
            
            this.pressed = true;
            x_mouse = event.x;
            y_mouse = event.y;
            redraw_canvas ();
            return false;
        }

        public override bool button_release_event (Gdk.EventButton event) {
            if (this.pressed) {
                this.pressed = false;
                x_mouse = -1;
                y_mouse = -1;
                this.dragging = false;
            }
            return false;
        }

        public override bool motion_notify_event (Gdk.EventMotion event) {
            if (this.pressed) {
                this.dragging = true;
                x_dragging_mouse = event.x;
                y_dragging_mouse = event.y;
                redraw_canvas();

            }
            return false;
        }

        public void read_wav_file (string path){
            var file = File.new_for_path (path);
            var file_stream = file.read ();
            var data_stream = new DataInputStream (file_stream);

            /* READ HEADER */
            string chunk_id;
            uint8[] chunk_id_array = new uint8[4];
            chunk_id_array[0] = data_stream.read_byte();
            chunk_id_array[1] = data_stream.read_byte();
            chunk_id_array[2] = data_stream.read_byte();
            chunk_id_array[3] = data_stream.read_byte();
            chunk_id = (string)chunk_id_array;

            uint32 chunk_size = data_stream.read_byte() | data_stream.read_byte() << 8 | 
                                data_stream.read_byte() << 16 | data_stream.read_byte() << 24;

            string format;
            uint8[] format_array = new uint8[4];
            format_array[0] = data_stream.read_byte();
            format_array[1] = data_stream.read_byte();
            format_array[2] = data_stream.read_byte();
            format_array[3] = data_stream.read_byte();
            format = (string)format_array;

            print("ChunkID\t\t\t\t"+chunk_id+"\n");
            print("ChunkSize\t\t\t"+chunk_size.to_string()+"\n");
            print("Format\t\t\t\t"+format+"\n");

            /*READ SUBHEADER */
            string sub_chunk_1_id;
            uint8[] sub_chunk_1_id_array = new uint8[4];
            sub_chunk_1_id_array[0] = data_stream.read_byte();
            sub_chunk_1_id_array[1] = data_stream.read_byte();
            sub_chunk_1_id_array[2] = data_stream.read_byte();
            sub_chunk_1_id_array[3] = data_stream.read_byte();
            sub_chunk_1_id = (string)sub_chunk_1_id_array;

            uint32 sub_chunk_1_size = data_stream.read_byte() | data_stream.read_byte() << 8 | 
                                data_stream.read_byte() << 16 | data_stream.read_byte() << 24;

            uint16 audio_format = data_stream.read_byte() | data_stream.read_byte() << 8;

            uint16 num_channel = data_stream.read_byte() | data_stream.read_byte() << 8;

            uint32 sample_rate = data_stream.read_byte() | data_stream.read_byte() << 8 | 
                                data_stream.read_byte() << 16 | data_stream.read_byte() << 24;

            uint32 byte_rate = data_stream.read_byte() | data_stream.read_byte() << 8 | 
                                data_stream.read_byte() << 16 | data_stream.read_byte() << 24;

            uint16 block_align = data_stream.read_byte() | data_stream.read_byte() << 8;

            uint16 bits_per_sample = data_stream.read_byte() | data_stream.read_byte() << 8;

            print("SubChunkID\t\t\t"+sub_chunk_1_id+"\n");
            print("SubChubkSize\t\t\t"+sub_chunk_1_size.to_string()+"\n");
            print("AudioFormat\t\t\t"+audio_format.to_string()+"\n");
            print("NumChannels\t\t\t"+num_channel.to_string()+"\n");
            print("SampleRate\t\t\t"+sample_rate.to_string()+"\n");
            print("ByteRate\t\t\t"+byte_rate.to_string()+"\n");
            print("BlockAlign\t\t\t"+block_align.to_string()+"\n");
            print("BitsPerSample\t\t\t"+bits_per_sample.to_string()+"\n");

            /*READ SUBHEADER */
            string sub_chunk_2_id;
            uint8[] sub_chunk_2_id_array = new uint8[4];
            sub_chunk_2_id_array[0] = data_stream.read_byte();
            sub_chunk_2_id_array[1] = data_stream.read_byte();
            sub_chunk_2_id_array[2] = data_stream.read_byte();
            sub_chunk_2_id_array[3] = data_stream.read_byte();
            sub_chunk_2_id = (string)sub_chunk_2_id_array;

            uint32 sub_chunk_2_size = data_stream.read_byte() | data_stream.read_byte() << 8 | 
                                data_stream.read_byte() << 16 | data_stream.read_byte() << 24;

            print("SubChunk2ID\t\t\t"+sub_chunk_2_id+"\n");
            print("SubChunk2Size\t\t\t"+sub_chunk_2_size.to_string()+"\n");

            uint16 sample;
            data_wav = new int16[sub_chunk_2_size/2];
            for (int i = 0; i < sub_chunk_2_size/2; i++){
                data_wav[i] = data_stream.read_byte() | data_stream.read_byte() << 8;
                if (max_data < ((int)(data_wav[i])).abs()){
                    max_data = ((int)(data_wav[i])).abs();
                }
            }
        }


        private void redraw_canvas () {
            var window = get_window ();
            if (null == window) {
                return;
            }

            var region = window.get_clip_region ();
            window.invalidate_region (region, true);
            window.process_updates (true);
        }
    }
}


int main (string[] args) {
    Gtk.init (ref args);
    var window = new Window ();
    window.set_default_size(400,180);
    window.title = "Processing wav files";
    var wave_form_widget = new Wave.WaveFormWidget ();
    wave_form_widget.set_wav_file("./sample26.wav");
    window.add (wave_form_widget);
    window.destroy.connect (Gtk.main_quit);
    window.show_all ();
    Gtk.main ();
    return 0;
}