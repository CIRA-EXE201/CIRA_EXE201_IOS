-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow users to upload to 'photos' bucket
CREATE POLICY "Allow authenticated uploads to photos bucket"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'photos');

-- Allow users to read their own photos (or public if that's the intention)
CREATE POLICY "Allow authenticated reads from photos bucket"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'photos');

-- Allow users to update their own photos
CREATE POLICY "Allow authenticated updates to photos bucket"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'photos' AND auth.uid() = owner);

-- Allow users to delete their own photos
CREATE POLICY "Allow authenticated deletes from photos bucket"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'photos' AND auth.uid() = owner);
