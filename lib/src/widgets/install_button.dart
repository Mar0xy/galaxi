import 'package:flutter/material.dart';
import 'package:galaxi/src/backend/api.dart';

/// A stateful install button that shows download/install progress directly
class InstallButton extends StatefulWidget {
  final int gameId;
  final String gameName;
  final VoidCallback? onInstallComplete;

  const InstallButton({
    super.key,
    required this.gameId,
    required this.gameName,
    this.onInstallComplete,
  });

  @override
  State<InstallButton> createState() => _InstallButtonState();
}

class _InstallButtonState extends State<InstallButton> {
  String _status = 'idle'; // idle, downloading, installing, complete, error
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startInstall() async {
    setState(() {
      _status = 'downloading';
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      // Start download and get installer path
      final installerPath = await startDownload(gameId: widget.gameId);
      
      // Give more time for download manager to start tracking progress
      await Future.delayed(const Duration(seconds: 1));
      
      // Poll for download progress
      bool downloadComplete = false;
      int nullProgressCount = 0;
      const maxNullCount = 60; // 30 seconds of null progress before giving up
      
      while (!downloadComplete) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final progress = await getDownloadProgress(gameId: widget.gameId);
          if (progress != null) {
            nullProgressCount = 0;
            // Use toInt() for comparison since we might have BigInt or int
            final downloaded = progress.downloadedBytes is BigInt 
                ? (progress.downloadedBytes as BigInt).toInt() 
                : progress.downloadedBytes as int;
            final total = progress.totalBytes is BigInt 
                ? (progress.totalBytes as BigInt).toInt() 
                : progress.totalBytes as int;
            
            final percent = total > 0 ? downloaded / total : 0.0;
            setState(() {
              _progress = percent;
            });
            
            if (progress.status == 'Completed') {
              downloadComplete = true;
            } else if (progress.status == 'Failed') {
              throw Exception('Download failed');
            } else if (progress.status == 'Cancelled') {
              throw Exception('Download cancelled');
            }
          } else {
            // Progress is null - download either hasn't started or has finished
            nullProgressCount++;
            // Only assume complete if we've seen some progress before
            // (null at the very start means download hasn't begun yet)
            if (nullProgressCount > maxNullCount) {
              throw Exception('Download timed out - no progress received');
            }
          }
        } catch (e) {
          // If getting progress fails, continue polling
          nullProgressCount++;
          if (nullProgressCount > maxNullCount) {
            throw Exception('Failed to get download progress: $e');
          }
        }
      }
      
      // Now install
      setState(() {
        _status = 'installing';
        _progress = 1.0;
      });
      
      // Install using the returned installer path
      await installGame(
        gameId: widget.gameId,
        installerPath: installerPath,
      );
      
      setState(() {
        _status = 'complete';
      });
      
      await Future.delayed(const Duration(seconds: 1));
      widget.onInstallComplete?.call();
      
    } catch (e) {
      setState(() {
        _status = 'error';
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case 'downloading':
        return Column(
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: null,
              icon: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Downloading... ${(_progress * 100).toStringAsFixed(0)}%'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        );
      case 'installing':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Installing...'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      case 'complete':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check, color: Colors.green),
          label: const Text('Installed!'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
      case 'error':
        return Column(
          children: [
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _startInstall,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Install'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        );
      default:
        return ElevatedButton.icon(
          onPressed: _startInstall,
          icon: const Icon(Icons.download),
          label: const Text('Install'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        );
    }
  }
}
