# Decoders, enabled when the binary is detected and the os is not Win32.

%include "utils.liq"

# Get_mime is not always defined
# so we define a default in this case..
my_get_mime = fun (_) -> ""
%ifdef get_mime
my_get_mime = get_mime
%endif
get_mime = my_get_mime

%ifdef add_decoder
if test_process("which flac") then
  log(level=3,"Found flac binary: enabling flac external decoder.")
  flac_p = "flac -d -c - 2>/dev/null"
  def test_flac(file) =
    if test_process("which metaflac") then
      channels = list.hd(get_process_lines("metaflac \
                                            --show-channels #{quote(file)} \
                                            2>/dev/null"))
      # If the value is not an int, this returns 0 and we are ok :)
      int_of_string(channels)
    else
      # Try to detect using mime test..
      mime = get_mime(file)
      if string.match(pattern="flac",file) then
        # We do not know the number of audio channels
        # so setting to -1
        (-1)
      else
        # All tests failed: no audio decodable using flac..
        0
      end
    end
  end
  add_decoder(name="FLAC",description="Decode files using the flac \
              decoder binary.", test=test_flac,flac_p)
else
  log(level=3,"flac binary not found: flac decoder disabled.")
end
%endif

if os.type != "Win32" then
  if test_process("which metaflac") then
   log(level=3,"Found metaflac binary: enabling flac external metadata \
                resolver.")
   def flac_meta(file)
     ret = get_process_lines("metaflac --export-tags-to=- \
                  #{quote(file)} 2>/dev/null")
     ret = list.map(string.split(separator="="),ret)
     # Could be made better..
     def f(l',l)=
       if list.length(l) >= 2 then
         list.append([(list.hd(l),list.nth(l,1))],l')
       else
         if list.length(l) >= 1 then
           list.append([(list.hd(l),"")],l')
         else
           l'
         end
       end
     end
     list.fold(f,[],ret)
   end
   add_metadata_resolver("FLAC",flac_meta)
  else
   log(level=3,"metaflac binary not found: flac metadata resolver disabled.")
  end
end

# A list of know extensions and content-type for AAC.
# Values from http://en.wikipedia.org/wiki/Advanced_Audio_Coding 
# TODO: can we register a setting for that ??
aac_mimes = ["audio/aac", "audio/aacp", "audio/3gpp", "audio/3gpp2", "audio/mp4",
             "audio/MP4A-LATM", "audio/mpeg4-generic", "audio/x-hx-aac-adts"]
aac_filexts = ["m4a", "m4b", "m4p", "m4v",
               "m4r", "3gp", "mp4", "aac"]

# Faad is not very selective so
# We are checking only file that
# end with a known extension or mime type
def faad_test(file) = 
  # Get the file's mime
  mime = get_mime(file)
  # Test mime
  if list.mem(mime,aac_mimes) then
    true
  else
    # Otherwise test file extension
    ret = string.extract(pattern='\.(.+)$',file)
      if list.length(ret) != 0 then
        ext = ret["1"]
        list.mem(ext,aac_filexts)
      else
        false
      end
  end
end

if os.type != "Win32" then
  if test_process("which faad") then
    log(level=3,"Found faad binary: enabling external faad decoder and \
                 metadata resolver.")
    faad_p = (fun (f) -> "faad -w #{quote(f)} 2>/dev/null")
    def test_faad(file) =
      if faad_test(file) then
        channels = list.hd(get_process_lines("faad -i #{quote(file)} 2>&1 | \
                                              grep 'ch,'"))
        ret = string.extract(pattern=", (\d) ch,",channels)
        ret = 
          if list.length(ret) == 0 then
          # If we pass the faad_test, chances are
          # high that the file will contain aac audio data..
            "-1"
          else
            ret["1"]
          end
        int_of_string(default=(-1),ret)
      else
        0
      end
    end
%ifdef add_oblivious_decoder
    add_oblivious_decoder(name="FAAD",description="Decode files using \
                          the faad binary.", test=test_faad, faad_p)
%endif
    def faad_meta(file) =
      if faad_test(file) then
        ret = get_process_lines("faad -i \
                     #{quote(file)} 2>&1")
        # Yea, this is tuff programming (again) !
        def get_meta(l,s)=
          ret = string.extract(pattern="^(\w+):\s(.+)$",s)
          if list.length(ret) > 0 then
            list.append([(ret["1"],ret["2"])],l)
          else
            l
          end
        end
        list.fold(get_meta,[],ret)
      else
        []
      end
    end
    add_metadata_resolver("FAAD",faad_meta)
  else
    log(level=3,"faad binary not found: faad decoder disabled.")
  end
end
