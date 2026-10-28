/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, photo capture,
// and error handling.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @Bindable var viewModel: StreamSessionViewModel
  var wearablesVM: WearablesViewModel
  @State private var translationViewModel = LiveTranslationViewModel()
  @State private var isTranslationExpanded = false
  @State private var showEnhancedTranslation = false

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          Image(uiImage: videoFrame)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundStyle(.white)
      }

      VStack(spacing: 12) {
        Spacer()

        if isTranslationExpanded {
          LiveTranslationOverlayPanel(viewModel: translationViewModel)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        HStack {
          Spacer()
          Button {
            showEnhancedTranslation = true
          } label: {
            Label("Translate", systemImage: "globe")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
              .background(
                LinearGradient(
                  colors: [Color.blue, Color.purple],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .clipShape(Capsule())
              .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
          }
        }
        .padding(.horizontal, 24)

        ControlsView(viewModel: viewModel)
          .padding(.horizontal, 24)
          .padding(.bottom, 24)
      }
    }
    .onDisappear {
      translationViewModel.cleanup()

      Task {
        if viewModel.streamingStatus != .stopped {
          await viewModel.stopSession()
        }
      }
    }
    .sheet(isPresented: $showEnhancedTranslation) {
      EnhancedLiveTranslationView()
    }
    // Show captured photos from DAT SDK in a preview sheet
    .sheet(isPresented: $viewModel.showPhotoPreview) {
      if let photo = viewModel.capturedPhoto {
        PhotoPreviewView(
          photo: photo,
          onDismiss: {
            viewModel.dismissPhotoPreview()
          }
        )
      }
    }
    .sheet(isPresented: $viewModel.showProduceInspection) {
      if let photo = viewModel.inspectionPhoto {
        ProduceInspectionView(image: photo)
          .onDisappear {
            viewModel.dismissProduceInspection()
          }
      }
    }
  }
}

struct ControlsView: View {
  var viewModel: StreamSessionViewModel

  var body: some View {
    HStack(spacing: 8) {
      CustomButton(
        title: "Stop streaming",
        style: .destructive,
        isDisabled: false
      ) {
        Task {
          await viewModel.stopSession()
        }
      }

      // One tap takes a photo and inspects the current frame (see UI_BUTTON_MERGE.md).
      CircleButton(icon: "camera.viewfinder", text: nil) {
        viewModel.capturePhoto()
        viewModel.inspectCurrentFrame()
      }
      .accessibilityIdentifier("capture_and_inspect_button")
      .accessibilityLabel("Capture photo and inspect produce")
    }
  }
}
