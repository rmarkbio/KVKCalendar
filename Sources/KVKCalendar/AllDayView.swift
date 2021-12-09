//
//  AllDayView.swift
//  KVKCalendar
//
//  Created by Sergei Kviatkovskii on 20.05.2021.
//

import UIKit

final class AllDayView: UIView {
    
    struct PrepareEvents {
        let events: [Event]
        let date: Date?
        let xOffset: CGFloat
        let width: CGFloat
    }
    
    struct Parameters {
        let prepareEvents: [PrepareEvents]
        let type: CalendarType
        var style: Style
        weak var delegate: TimelineDelegate?
    }
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private var containerView: UIView!
    private let linePoints: [CGPoint]
    private var params: Parameters
    private var style: AllDayStyle
    
    let items: [[AllDayEvent]]
    
    init(parameters: Parameters, frame: CGRect) {
        self.params = parameters
        self.style = params.style.allDay
        
        self.items = parameters.prepareEvents.compactMap({ item -> [AllDayEvent] in
            return item.events.compactMap({ AllDayEvent(date: $0.start, event: $0, xOffset: item.xOffset, width: item.width) })
        })
        self.linePoints = parameters.prepareEvents.compactMap({ CGPoint(x: $0.xOffset, y: 0) })
        
        super.init(frame: frame)
        setUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func calculateFrame(index: Int, countEvents: Int, width: CGFloat, height: CGFloat) -> CGRect {
        var newSize: CGSize
        var newPoint: CGPoint
        let newY = height * CGFloat(index / 2)
        let newWidth = width * 0.5
        
        if countEvents == (index + 1) {
            newSize = CGSize(width: index % 2 == 0 ? width : newWidth, height: height)
            newPoint = CGPoint(x: index % 2 == 0 ? 0 : newWidth, y: newY)
        } else if index % 2 == 0 {
            newSize = CGSize(width: newWidth, height: height)
            newPoint = CGPoint(x: 0, y: newY)
        } else {
            newSize = CGSize(width: newWidth, height: height)
            newPoint = CGPoint(x: newWidth, y: newY)
        }
        
        newSize.width -= style.offsetWidth
        newSize.height -= style.offsetHeight
        newPoint.y += 1
        
        return CGRect(origin: newPoint, size: newSize)
    }
    
    private func setupView() {
        backgroundColor = style.backgroundColor
        
        let widthTitle = params.style.timeline.widthTime + params.style.timeline.offsetTimeX + params.style.timeline.offsetLineLeft
        titleLabel.frame = CGRect(x: style.offsetX, y: 0,
                                  width: widthTitle - style.offsetX,
                                  height: style.height)
        titleLabel.font = style.fontTitle
        titleLabel.textColor = style.titleColor
        titleLabel.textAlignment = style.titleAlignment
        titleLabel.text = style.titleText
        
        let x = titleLabel.frame.width + titleLabel.frame.origin.x
        
        containerView = style.mode == .scroll ? setupScrollView(x) : setupMoreContainerView(x)
        
        let longTap = UILongPressGestureRecognizer(target: self, action: #selector(addNewEvent))
        longTap.minimumPressDuration = params.style.timeline.minimumPressDuration
        addGestureRecognizer(longTap)
        
        addSubview(titleLabel)
        addSubview(containerView)
    }
    
    private func setupScrollView(_ xOffset: CGFloat ) -> UIScrollView {
        
        let scrollView = UIScrollView()
        
        let scrollFrame = CGRect(origin: CGPoint(x: xOffset, y: 0),
                                 size: CGSize(width: bounds.size.width - xOffset, height: bounds.size.height))
        
        let maxItems = CGFloat(items.max(by: { $0.count < $1.count })?.count ?? 0)
        scrollView.frame = scrollFrame
        
        switch params.type {
        case .day:
            scrollView.contentSize = CGSize(width: scrollFrame.width, height: (maxItems / 2).rounded(.up) * style.height)
        case .week:
            scrollView.contentSize = CGSize(width: scrollFrame.width, height: maxItems * style.height)
        default:
            break
        }
        
        return scrollView
    }
    
    private func setupMoreContainerView(_ xOffset: CGFloat) -> UIView {
        let view = UIView()
        view.clipsToBounds = true
        
        view.frame = CGRect(origin: CGPoint(x: xOffset, y: 0),
                                 size: CGSize(width: bounds.size.width - xOffset, height: bounds.size.height))
        
        return view
    }
    
    private func createEventViews() {
        switch params.type {
        case .day:
            if let item = items.first {
                item.enumerated().forEach { (event) in
                    let frameEvent = calculateFrame(index: event.offset,
                                                    countEvents: item.count,
                                                    width: containerView.bounds.width,
                                                    height: style.height)
                    let eventView = AllDayEventView(style: style, event: event.element.event, frame: frameEvent)
                    eventView.delegate = self
                    containerView.addSubview(eventView)
                }
            }
        case .week:
            items.enumerated().forEach { item in
                var eventsDisplayed = 0
                for event in item.element.enumerated() {
                    let x = item.offset == 0 ? 0 : event.element.xOffset
                    let y = style.height * CGFloat(event.offset)
                    let frameEvent = CGRect(origin: CGPoint(x: x, y: y),
                                            size: CGSize(width: event.element.width - style.offsetWidth,
                                                         height: style.height - style.offsetHeight))
                    
                    if style.mode == .more && isMoreRequired(for: item.element.count, added: eventsDisplayed) {
                        let bt = createMoreButton(frameEvent, for: item.element.count - eventsDisplayed)
                        bt.tag = item.offset
                        containerView.addSubview(bt)
                        break
                    }
    
                    let eventView = AllDayEventView(style: style, event: event.element.event, frame: frameEvent)
                    eventView.delegate = self
                    containerView.addSubview(eventView)
                    eventsDisplayed += 1
                }
            }
            
            if style.isPinned {
                linePoints.enumerated().forEach { (point) in
                    let x = point.offset == 0 ? containerView.frame.origin.x : (point.element.x + containerView.frame.origin.x)
                    let line = createVerticalLine(pointX: x)
                    addSubview(line)
                }
            }
        default:
            break
        }
    }
    
    private func isMoreRequired(for all: Int, added: Int) -> Bool {
        
        let maxEvents = Int(style.maxHeight / style.height)
        
        return (maxEvents - added) == 1 && maxEvents < all
    }
    
    private func createVerticalLine(pointX: CGFloat) -> VerticalLineView {
        let frame = CGRect(x: pointX, y: 0, width: params.style.timeline.widthLine, height: bounds.height)
        let line = VerticalLineView(frame: frame)
        line.backgroundColor = params.style.timeline.separatorLineColor
        line.isHidden = !params.style.week.showVerticalDayDivider
        return line
    }
    
    @objc private func tapMore(_ sender: UIButton) {
        let item = items[sender.tag]
        
        guard let event = item.first else { return  }
        
        let frame = containerView.convert(sender.frame, to: superview?.superview)
        params.delegate?.didSelectAllDayMore(items[sender.tag].map{ $0.event }, frame: frame)
    }
    
    @objc func addNewEvent(gesture: UILongPressGestureRecognizer) {
        
        var point = gesture.location(in: self)
        point = CGPoint(x: point.x - containerView.frame.origin.x, y: point.y)
        let start = params.prepareEvents.first(where: { $0.xOffset < point.x && point.x < ($0.xOffset + $0.width)})?.date ?? Date()
        
        switch gesture.state {
        case .began:
            UIImpactFeedbackGenerator().impactOccurred()
        case .ended, .failed, .cancelled:
            var newEvent = Event(ID: Event.idForNewEvent)
            newEvent.start = start
            newEvent.end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
            newEvent.text = params.style.event.textForNewEvent
            newEvent.isAllDay = true
            params.delegate?.didAddNewEvent(newEvent, minute: start.minute, hour: start.hour, point: point)
        default:
            break
        }
    }
    
    private func createMoreButton(_ frame: CGRect, for count: Int) -> UIButton {
        let bt = UIButton(frame: frame)
        bt.setTitle(style.moreText.replacingOccurrences(of: "%@", with: "\(count)"), for: .normal)
        bt.setTitleColor(style.titleColor, for: .normal)
        bt.titleLabel?.font = style.fontTitle
        bt.contentEdgeInsets = .init(top: 0, left: 5, bottom: 0, right: 0);
        bt.contentHorizontalAlignment = .left
        bt.addTarget(self, action: #selector(tapMore), for: .touchUpInside)
        return bt
    }
    
}

extension AllDayView: AllDayEventDelegate {
    
    func didSelectAllDayEvent(_ event: Event, frame: CGRect?) {
        params.delegate?.didSelectEvent(event, frame: frame)
    }
}

extension AllDayView: CalendarSettingProtocol {
    
    var currentStyle: Style {
        params.style
    }
    
    func reloadFrame(_ frame: CGRect) {
        
    }
    
    func updateStyle(_ style: Style) {
        params.style = style
        setUI()
    }
    
    func setUI() {
        setupView()
        createEventViews()
    }
    
}
