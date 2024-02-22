
images_named_dir = "#{Dir.pwd}/images_named/"
p "gonna re-write #{images_named_dir}"
Dir.glob("#{images_named_dir}*").sort.each do |f|
  filename = File.basename(f, File.extname(f))
  outfilename = filename.split("__", 2)[1] + File.extname(f).gsub('JPEG','jpg').gsub('JPG','jpg')
  p "writing #{outfilename}"
  File.rename(f, "#{images_named_dir}#{outfilename}")
end

# also do /images/
# but split on single _ (instead of double __)
imagesdir = "#{Dir.pwd}/images/"
p "gonna re-write #{imagesdir}"
Dir.glob("#{imagesdir}*").sort.each do |f|
  filename = File.basename(f, File.extname(f))
  outfilename = filename.split("_", 2)[1] + File.extname(f).gsub('JPEG','jpg').gsub('JPG','jpg')
  p "writing #{outfilename}"
  File.rename(f, "#{imagesdir}#{outfilename}")
end
